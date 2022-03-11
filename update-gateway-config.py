import yaml
import os

yaml_path = os.environ['YAML_PATH']

with open(yaml_path + '/' + 'cluster1-gateway.yaml', 'r') as yaml_file:
    yaml_data = yaml.full_load(yaml_file)

yaml_data['spec']['servers'][0]['hosts'].append('cluster1-tenantc-ns/*')

with open(yaml_path + '/' + 'cluster1-gateway.yaml', 'w') as yaml_file:
    yaml.dump(yaml_data, yaml_file)