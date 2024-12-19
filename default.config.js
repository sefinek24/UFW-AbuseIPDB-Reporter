exports.MAIN = {
	LOG_FILE: '/var/log/ufw.log',
	CACHE_FILE: '/tmp/ufw-abuseipdb-reporter.cache',

	ABUSEIPDB_API_KEY: '',
	GITHUB_REPO: 'https://github.com/sefinek/UFW-AbuseIPDB-Reporter',

	REPORT_INTERVAL: 12 * 60 * 60 * 1000, // 12h
};

exports.REPORT_COMMENT = (timestamp, srcIp, dstIp, proto, spt, dpt, ttl, len, tos) => {
	return `Blocked by UFW (${proto} on ${dpt})
Source port: ${spt}
TTL: ${ttl || 'N/A'}
Packet length: ${len || 'N/A'}
TOS: ${tos || 'N/A'}

This report (for ${srcIp}) was generated by:
https://github.com/sefinek/UFW-AbuseIPDB-Reporter`; // Please do not remove the URL to the repository of this script. I would be really grateful. 💙
};

// See: https://www.abuseipdb.com/categories
exports.DETERMINE_CATEGORIES = (proto, dpt) => {
	const categories = {
		TCP: {
			22: '14,22,18', // Port Scan | SSH | Brute-Force
			80: '14,21', // Port Scan | Web App Attack
			443: '14,21', // Port Scan | Web App Attack
			8080: '14,21', // Port Scan | Web App Attack
			25: '14,11', // Port Scan | Email Spam
			21: '14,5,18', // Port Scan | FTP Brute-Force | Brute-Force
			53: '14,1,2', // Port Scan | DNS Compromise | DNS Poisoning
			23: '14,15,18', // Port Scan | Hacking | Brute-Force
			3389: '14,15,18', // Port Scan | Hacking | Brute-Force
			3306: '14,16', // Port Scan | SQL Injection
			6666: '14,8', // Port Scan | Fraud VoIP
			6667: '14,8', // Port Scan | Fraud VoIP
			6668: '14,8', // Port Scan | Fraud VoIP
			6669: '14,8', // Port Scan | Fraud VoIP
			9999: '14,6', // Port Scan | Ping of Death
		},
		UDP: {
			53: '14,1,2', // Port Scan | DNS Compromise | DNS Poisoning
			123: '14,17', // Port Scan | Spoofing
		},
	};

	return categories[proto]?.[dpt] || '14'; // Port Scan
};