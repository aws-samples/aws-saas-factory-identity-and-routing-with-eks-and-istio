# SaaS Identity and Routing with Istio Service Mesh and Amazon EKS

The code shared here is intended to provide a sample implementation of a SaaS Identity and Routing solution based on Istio Service Mesh and Amazon EKS. The goal is to provide SaaS developers and architects with working code that will illustrate how multi-tenant SaaS applications can be design and delivered on AWS using Istio Service Mesh and Amazon EKS. The solution implements an identity model that simplifies the mapping of individual tenants and routing of traffic to isolated  tenant environments. The focus here is more on giving developers a view into the working elements of the solution without going to the extent of making a full, production-ready solution.

Note that the instructions below are intended to give you step-by-step, how-to instructions for getting this solution up and running in your own AWS account. For a general description and overview of the solution, please see the 
[blog post here](https://aws.amazon.com/blogs/apn/saas-identity-and-routing-with-istio-service-mesh-and-amazon-eks/).

## Setting up the environment

> :warning: The Cloud9 workspace should be built by an IAM user with Administrator privileges, not the root account user. Please ensure you are logged in as an IAM user, not the root account user.

1. Create new Cloud9 Environment
    * Launch Cloud9 in your closest region Ex: `https://us-west-2.console.aws.amazon.com/cloud9/home?region=us-west-2`
    * Select Create environment
    * Name it whatever you want, click Next.
    * Choose “t3.small” for instance type, take all default values and click Create environment
2. Create EC2 Instance Role
    * Follow this [deep link](https://console.aws.amazon.com/iam/home#/roles$new?step=review&commonUseCase=EC2%2BEC2&selectedUseCase=EC2&policies=arn:aws:iam::aws:policy%2FAdministratorAccess) to create an IAM role with Administrator access.
    * Confirm that AWS service and EC2 are selected, then click Next to view permissions.* Confirm that AdministratorAccess is checked, then click `Next: Tags` to assign tags.
    * Take the defaults, and click `Next: Review` to review.
    * Enter `istio-ref-arch-admin` for the Name, and click `Create role`.
3. Remove managed credentials and attach EC2 Instance Role to Cloud9 Instance
    * Click the gear in the upper right-hand corner of the IDE which opens settings. Click the `AWS Settings` on the left and under `Credentials` slide the button to the left for `AWS Managed Temporary Credentials. The button should be greyed out when done with an x to the right indicating it's off.
    * Click the round Button with an alphabet in the upper right-hand corner of the IDE and click `Manage EC2 Instance`. This will take you to the EC2 portion of the AWS Console
    * Right-click the EC2 instance and in the fly-out menu, click `Security` -> `Modify IAM Role`
    * Choose the Role you created in step 3 above. It should be titled "istio-ref-arch-admin" and click `Save`.
4. Clone the repo and run the setup script
    * Return to the Cloud9 IDE
    * In the upper left part of the main screen, click the round green button with a `+` on it and click `New Terminal`
    * Enter the following in the terminal window

    ```bash
    git clone https://github.com/aws-samples/aws-saas-factory-identity-and-routing-with-eks-and-istio.git
    cd aws-saas-factory-identity-and-routing-with-eks-and-istio
    chmod +x setup.sh
    ./setup.sh
   ```

   This [script](./setup.sh) sets up all Kubernetes tools, updates the AWS CLI and installs other dependencies that we'll use later. Take note of the final output of this script. If everything worked correctly, you should see the message that the you're good to continue creating the EKS cluster. If you do not see this message, please do not continue. Ensure that the Administrator EC2 role was created and successfully attached to the EC2 instance that's running your Cloud9 IDE. Also ensure you turned off `AWS Managed Credentials` inside your Cloud9 IDE (refer to steps 2 and 3).

5. Create the EKS Cluster
    * Run the following script to create a cluster configuration file, and subsequently provision the cluster using `eksctl`:

    ```bash
    chmod +x deploy1.sh
    ./deploy1.sh
    ```

    The cluster will take approximately 30 minutes to deploy.

    After EKS Cluster is set up, the script also deploys AWS Load Balancer Controller on the cluster.

6. Deploy Istio Service Mesh
    > :warning: Close the terminal window that you created the cluster in, and open a new terminal before starting this step otherwise you may get errors about your AWS_REGION not set.
    * Open a **_NEW_** terminal window and `cd` back into `aws-saas-factory-identity-and-routing-with-eks-and-istio` and run the following script:

    ```bash
    chmod +x deploy2.sh
    ./deploy2.sh
    ```

    This [script](./deploy2.sh) deploys the Istio Service Mesh demo profile, disabling the Istio Egress Gateway, while enabling the Istio Ingress Gateway along with Kubernetes annotations that signal the AWS Load Balancer Controller to automatically deploy a Network Load Balancer and associate it with the Ingress Gateway service.

7. Deploy Cognito User Pools
    > :warning: Close the terminal window that you create the cluster in, and open a new terminal before starting this step otherwise you may get errors about your AWS_REGION not set.
    * Open a **_NEW_** terminal window and `cd` back into `aws-saas-factory-identity-and-routing-with-eks-and-istio` and run the following script:

    ```bash
    chmod +x deploy-userpools.sh
    ./deploy-userpools.sh
    ```

    This [script](./deploy-userpools.sh) deploys Cognito User Pools for two (2) example tenants: tenanta and tenantb. Within each User Pool. The script will ask for passwords that will be set for each user.

    The script also generates the following YAML files for OIDC proxy configuration which will be deployed in the next step: 

    1. oauth2-proxy configuration for each tenant

    2. External Authorization Policy for Istio Ingress Gateway

8. Configure Istio Ingress Gateway
    > :warning: Close the terminal window that you create the cluster in, and open a new terminal before starting this step otherwise you may get errors about your AWS_REGION not set.
    * Open a **_NEW_** terminal window and `cd` back into `aws-saas-factory-identity-and-routing-with-eks-and-istio` and run the following script:

    ```bash
    chmod +x configure-istio.sh
    ./configure-istio.sh
    ```

    This [script](./configure-istio.sh) creates the following in preparation for configuring Istio Ingress Gateway:

    a. Self-signed Root CA Cert and Key

    b. Istio Ingress Gateway Cert signed by the Root CA

    It also completes the following steps:

    a. Creates TLS secret object for Istio Ingress Gateway Cert and Key

    b. Creates namespaces for Gateway, Envoy Reverse Proxy, OIDC Proxies, and the example tenants

    c. Deploys an Istio Gateway resource

    d. Deploys an Envoy reverse proxy
       - Create an ECR Repo for Envoy container image
       - Build Envoy container image adding the configuration YAML
       - Push the container image to the ECR Repo
       - Deploy the container image

    e. Deploy oauth2-proxy along with the configuration generated in the Step 8

    f. Adds an Istio External Authorization Provider definition pointing to the Envoy Reverse Proxy

9. Deploy Tenant Application Microservices
    > :warning: Close the terminal window that you create the cluster in, and open a new terminal before starting this step otherwise you may get errors about your AWS_REGION not set.
    * Open a **_NEW_** terminal window and `cd` back into `aws-saas-factory-identity-and-routing-with-eks-and-istio` and run the following script:

    ```bash
    chmod +x deploy-tenant-services.sh
    ./deploy-tenant-services.sh
    ```

    This [script](./deploy-tenant-services.sh) creates the service dpeloyments for the two (2) sample tenants, along with Istio VirtualService constructs that define the routing rules.

10. Once finished running all the above steps, the bookinfo app can be accessed using the following steps.

    a. Since the sample tenants are built using the DNS domain example.com, domain name entries are made into the local desktop/laptop hosts file. For Linux/MacOS the file is /etc/hosts and on Windows it is C:\Windows\System32\drivers\etc\hosts.

    b. Wait for the Network Load Balancer instance status, in AWS Management Console, to change from Provisioning to Active.

    c. Run the following command in the Cloud9 shell
    ```bash
    chmod +x hosts-file-entry.sh
    ./hosts-file-entry.sh
    ```

    d. Append the output of the command into the local hosts file. It identifies the load balancer instance associated with the Istio Ingress Gateway, and looks up the public IP addresses assigned to it.

    e. To avoid TLS cert conflicts, configure the browser on desktop/laptop with a new profiles

    f. The browser used to test this deployment was Mozilla Firefox, in which a new profile can be created by pointing the browser to "about:profiles"

    g. Create a new profile, such as, "istio-saas"

    h. After creating the profile, click on the "Launch profile in new browser"

    i. In the browser, open two tabs, one for each of the following URLs:

    ```
       https://tenanta.example.com/bookinfo

       https://tenantb.example.com/bookinfo
    ```

    j. Because of self-signed TLS certificates, you may received a certificate related error or warning from the browser

    k. When the login prompt appears:

       In the browser windows with the "istio-saas" profile, login with:

    ```
       user1@tenanta.com

       user1@tenantb.com
    ```
       This should result in displaying the bookinfo page

11. Tenant Onboarding

    a. Add User Pools for new tenants
    
    ```bash
    chmod +x add-userpools.sh
    ./add-userpools.sh
    ```

    b. Re-configure Istio Ingress Gateway and Envoy Reverse Proxy
    
    ```bash
    chmod +x update-istio-config.sh
    ./update-istio-config.sh
    ```
    c. Deploy new tenant's microservices

    ```bash
    chmod +x update-tenant-services.sh
    ./update-tenant-services.sh
    ```
    d. Run the following command in the Cloud9 shell
    ```bash
    chmod +x update-hosts-file-entry.sh
    ./update-hosts-file-entry.sh
    ```

    e. Append the output of the command into the local hosts file. It identifies the load balancer instance associated with the Istio Ingress Gateway, and looks up the public IP addresses assigned to it.

    f. In the browser window with the "istio-saas" profile, open another tab for:

    ```
       https://tenantc.example.com/bookinfo
    ```

    g. Because of self-signed TLS certificates, you may received a certificate related error or warning from the browser

    h. When the login prompt appears, login with:

    ```
       user1@tenantc.com
    ```

       This should result in displaying the bookinfo page

## Cleanup

1. The deployed components can be cleaned up by running the following:

    ```bash
    chmod +x cleanup.sh
    ./cleanup.sh
    ```

    This [script](./cleanup.sh) will 

    a. Delete the Cognito User Pools and the assoicated Hosted UI domains

    b. Uninstall AWS Load Balancer Controller

    c. Delete the EKS Cluster

    d. Disable the KMS Master Key and removes the alias

    e. Delete EC2 Key-Pair

2. You can also delete

    a. The EC2 Instance Role `istio-ref-arch-admin`

    b. The Cloud9 Environment

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

