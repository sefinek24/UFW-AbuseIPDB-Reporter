const fs = require('node:fs');
const { CACHE_FILE, REPORT_INTERVAL } = require('../config.js').MAIN;
const log = require('./log.js');

const reportedIps = new Map();

const loadReportedIps = () => {
	if (fs.existsSync(CACHE_FILE)) {
		fs.readFileSync(CACHE_FILE, 'utf8')
			.split('\n')
			.forEach(line => {
				const [ip, time] = line.split(' ');
				if (ip && time) reportedIps.set(ip, Number(time));
			});
		log(0, `Loaded ${reportedIps.size} IPs from ${CACHE_FILE}`);
	} else {
		log(0, `${CACHE_FILE} does not exist. No data to load.`);
	}
};

const saveReportedIps = () => fs.writeFileSync(CACHE_FILE, Array.from(reportedIps).map(([ip, time]) => `${ip} ${time}`).join('\n'), 'utf8');

const isIpReportedRecently = ip => {
	const now = Math.floor(Date.now() / 1000);
	return reportedIps.has(ip) && (now - reportedIps.get(ip) < REPORT_INTERVAL);
};

const markIpAsReported = ip => reportedIps.set(ip, Math.floor(Date.now() / 1000));

module.exports = { loadReportedIps, saveReportedIps, isIpReportedRecently, markIpAsReported };