# package-monitoring-comments.md

Stuff that must be improved on the 
package-monitoring-*.nd files


## prometheus package-monitoring-prometheus.md

there are several pods named prometheus-<something> what are they doing


## loki package-monitoring-loki.md

there are several pods named loki-<something> what are they doing


## otel package-monitoring-otel.md

No need to write about the **Application Integration** in the different languages.
we will rather create a package-monitoring-sovdev-logger.md where we put this doc.
That goes for all references in the other package-monitoring-*.md as well

In the sovdev-infrastructure (we will rename urbalurba-infrastructure) we dont use auth for clients. write short where users can go to learn how to set up auth if needed.


## grafana package-monitoring-grafana.md

It says: 
**Authentication**:
- **Default**: admin/SecretPassword1 (configured in Helm values)
Is the admin/SecretPassword1 hardcoded in the helm chart ?


we need a section about how to add new dashboards (and update/delete them)

## sovdev-logger  package-monitoring-sovdev-logger.md

this file will be doc on how to use the sovdev-logger in the various languages
