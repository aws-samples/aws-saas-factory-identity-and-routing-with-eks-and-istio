import yaml
import os

yaml_path = os.environ['YAML_PATH']

with open(yaml_path + '/' + 'cluster1-auth-policy.yaml', 'r') as yaml_file:
    yaml_data = yaml.full_load(yaml_file)

yaml_data['spec']['rules'][0]['to'][0]['operation']['hosts'].append('tenantc.example.com')

with open(yaml_path + '/' + 'cluster1-auth-policy.yaml', 'w') as yaml_file:
    yaml.dump(yaml_data, yaml_file)