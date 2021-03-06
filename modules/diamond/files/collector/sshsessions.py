# coding=utf-8
"""
Collect number of open ssh / mosh sessions

"""
import subprocess
import diamond.collector


class SSHSessionsCollector(diamond.collector.Collector):
    def get_default_config(self):
        """
        Returns the default collector settings
        """
        config = super(SSHSessionsCollector, self).get_default_config()
        config.update({
            'method':   'Threaded',
        })
        return config

    def collect(self):
        who_output = subprocess.check_output('/usr/bin/who').decode('utf-8')

        # weed out empty lines
        sessions = [l for l in who_output.split("\n") if l.strip() != ""]
        self.publish('open_sessions', len(sessions))
