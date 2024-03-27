#### Send EJBCA CE container logs to Graylog syslog server container

Graylog can consume GELF (Graylog Extended Log Format) - similar to Logstash, we could send the stdout logs over udp using docker gelf logging driver.

The collected data can be processed in form of advance searches to perform analysis, create custom dashboards and trigger event-based notifications.

Given a Graylog docker image, this example highlights building a compose file to eventually run 4 container layers side by side.

##### Get started

- Run docker compose up (or docker-compose up).
- Using a browser, navigate to http://127.0.0.1:9000 as specified in the HTTP_EXTERNAL_URI of the Graylog container, use user admin. [1]
- After login, under System → Inputs → select input type *GELF UDP* and click Launch new input.
- Add a title and fine-tine if required, then Save.
- At this point, we can start exploring [the log lines](sample_loglines.png), create Extractors, searches and create dashboards. [2]

##### Notes
1. You should consider changing the default password of Graylog http interface by replacing the value of GRAYLOG_ROOT_PASSWORD_SHA2.

This can be used to generate a new password hash:
```bash
// MacOS
echo -n "Enter Password: " && head -1 < /dev/stdin | tr -d '\n' | shasum -a 256 | cut -d " " -f1

// Linux
echo -n "Enter Password: " && head -1 < /dev/stdin | tr -d '\n' | sha256sum | cut -d " " -f1
```
* Always refer to Graylog docs: https://docs.graylog.org/docs/docker
2. Read how to deal with Extractors, Events, Visualize Searches and create Dashboards in EJBCA docs: [Integrating EJBCA with Graylog](https://doc.primekey.com/ejbca/ejbca-integration/integrating-with-third-party-applications/integrating-ejbca-with-graylog).
3. The same approach applies to both EJBCA and Signserver containers.
