const fs = require('node:fs');
const chokidar = require('chokidar');
const isLocalIP = require('./utils/isLocalIP.js');
const { loadReportedIps, saveReportedIps, isIpReportedRecently, markIpAsReported } = require('./utils/cache.js');
const log = require('./utils/log.js');
const axios = require('./services/axios.js');
const config = require('./config.js');
const { LOG_FILE, ABUSEIPDB_API_KEY } = config.MAIN;

let fileOffset = 0;

const reportToAbuseIpDb = async (ip, categories, comment) => {
	try {
		const { data } = await axios.post('https://api.abuseipdb.com/api/v2/report', new URLSearchParams({ ip, categories, comment }), {
			headers: { 'Key': ABUSEIPDB_API_KEY },
		});

		log(0, `Successfully reported IP ${ip} (score: ${data.data.abuseConfidenceScore})`);
		return true;
	} catch (err) {
		log(2, `${err.message}\n${JSON.stringify(err.response.data)}`);
		return false;
	}
};

const determineCategories = (proto, dpt) => {
	const categories = {
		TCP: {
			22: '14,22,18', 80: '14,21', 443: '14,21', 8080: '14,21',
			25: '14,11', 21: '14,5,18', 53: '14,1,2', 23: '14,15,18',
			3389: '14,15,18', 3306: '14,16', 6666: '14,8',
			6667: '14,8', 6668: '14,8', 6669: '14,8', 9999: '14,6',
		},
		UDP: {
			53: '14,1,2', 123: '14,17',
		},
	};

	return categories[proto]?.[dpt] || '14';
};

const processLogLine = async line => {
	if (!line.includes('[UFW BLOCK]')) return log(1, `Ignoring line: ${line}`);

	const match = {
		timestamp: line.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2})?/)[0],
		srcIp: line.match(/SRC=([\d.]+)/)?.[1],
		dstIp: line.match(/DST=([\d.]+)/)?.[1],
		proto: line.match(/PROTO=(\S+)/)?.[1],
		spt: line.match(/SPT=(\d+)/)?.[1],
		dpt: line.match(/DPT=(\d+)/)?.[1],
		ttl: line.match(/TTL=(\d+)/)?.[1],
		len: line.match(/LEN=(\d+)/)?.[1],
		tos: line.match(/TOS=(\S+)/)?.[1],
	};

	const { srcIp, proto, dpt } = match;
	if (!srcIp) {
		log(1, `Missing SRC in log line: ${line}`);
		return;
	}

	if (isLocalIP(srcIp)) {
		log(0, `Ignoring local/private IP: ${srcIp}`);
		return;
	}

	if (isIpReportedRecently(srcIp)) {
		log(0, `IP ${srcIp} reported recently`);
		return;
	}

	const categories = determineCategories(proto, dpt);
	const comment = config.REPORT_COMMENT(match.timestamp, srcIp, match.dstIp, proto, match.spt, dpt, match.ttl, match.len, match.tos);

	log(0, `Reporting IP ${srcIp} (${proto} ${dpt}) with categories ${categories}`);

	if (await reportToAbuseIpDb(srcIp, categories, comment)) {
		markIpAsReported(srcIp);
		saveReportedIps();
	}
};

const startMonitoring = () => {
	loadReportedIps();

	if (!fs.existsSync(LOG_FILE)) {
		log(2, `Log file ${LOG_FILE} does not exist.`);
		return;
	}

	fileOffset = fs.statSync(LOG_FILE).size;

	chokidar.watch(LOG_FILE, { persistent: true, ignoreInitial: true })
		.on('change', path => {
			const stats = fs.statSync(path);
			if (stats.size < fileOffset) {
				log(1, 'File truncated. Resetting offset...');
				fileOffset = 0;
			}

			fs.createReadStream(path, { start: fileOffset, encoding: 'utf8' }).on('data', chunk => {
				chunk.split('\n').filter(line => line.trim()).forEach(processLogLine);
			}).on('end', () => {
				fileOffset = stats.size;
			});
		});

	log(0, `Now monitoring ${LOG_FILE}`);
};

startMonitoring();