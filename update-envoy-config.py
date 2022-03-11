import yaml

new_listener_yaml = """
name: tenantc
domains: ["tenantc.example.com"]
routes:
- match:
   prefix: "/"
  route:
    cluster: tenantc_oidc_proxy
"""

new_cluster_yaml = """
name: tenantc_oidc_proxy
connect_timeout: 30s
type: LOGICAL_DNS
dns_lookup_family: AUTO
lb_policy: ROUND_ROBIN
load_assignment:
  cluster_name: tenantc_oidc_proxy
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          socket_address:
            address: oauth2-proxy.cluster1-tenantc-oidc-proxy-ns.svc.cluster.local
            port_value: 80

"""

new_listener_data = yaml.full_load(new_listener_yaml)
new_cluster_data = yaml.full_load(new_cluster_yaml)

with open('envoy.yaml', 'r') as yaml_file:
    yaml_data = yaml.full_load(yaml_file)
    
yaml_data['static_resources']['listeners'][0]['filter_chains'][0]['filters'][0]['typed_config']['route_config']['virtual_hosts'].append(new_listener_data)

yaml_data['static_resources']['clusters'].append(new_cluster_data)

with open('envoy.yaml', 'w') as yaml_file:
    yaml.dump(yaml_data, yaml_file)