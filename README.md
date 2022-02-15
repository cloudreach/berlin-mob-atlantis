# berlin-mob-atlantis
berlin-mob-atlantis
a# berlin-mob-atlantis
This repo is to showcase the usage of Atlantis with a simple terraform project

# Set up environment

## Create a bucket for S3 backend
```bash 
export BUCKET_NAME=berlin-mob-atlantis

aws s3api create-bucket --bucket $BUCKET_NAME --create-bucket-configuration LocationConstraint=eu-central-1
{
    "Location": "http://berlin-mob-atlantis.s3.amazonaws.com/"
}
```
## Plan and apply

```bash

cd src
terraform init -backend-config=env/sandbox.backend.tfvars  \
        -backend=true \
        -get=true 

terraform apply

```

## Verify provisioned resource

```bash
aws iam get-policy --policy-arn $(terraform output -raw policy_arn)
```

# Test Atlantis locally with this repo

1. Download atlantis [atlantis_darwin_amd64.zip](https://github.com/runatlantis/atlantis/releases/download/v0.18.2/atlantis_darwin_amd64.zip) or your version [here](https://github.com/runatlantis/atlantis/releases)
2.  unzip the content and move it to your path
  ```bash
  cp ~/Downloads/atlantis /usr/local/bin/
  atlantis version
  # atlantis 0.18.2
  ```
3.  intall ngrok and start a socket on port 4141
    ```
    brew install ngrok/ngrok/ngrok
    ngrok http 4141

    ```
4.  Get your ngrok address
    ![ngrok](ngrokURL.png)
4.  Set Env Variables for your ngrok
    ```bash
    URL="https://<YOUR HOSTNAME>.ngrok.io"
    # e.g URL=  https://58b9-95-90-238-57.ngrok.io

    #a random string
    SECRET=$(openssl rand -hex 12)
    ```
5. add a webhook to this repo, under Settings --> Hooks --> Add Webhook 
    * Payload URL = \<URL>/events (e.g. https://58b9-95-90-238-57.ngrok.io/events )
    * contentType = application/json
    * Secret = \<SECRET>
    * check the boxes
        * `Pull request reviews`
        * `Pushes`
        * `Issue comments`
        * `Pull requests`
    * leave Active checked
    * click Add webhook
6. add a token for atlantis in your repo:
    - in Github go to your profile icon, --> Settings --> Developer Settings --> Personal Access Token --> Generate new token
    - Note: `Atlantis`
    - select: `repo` only
    - Generate Token
7. Export the token in a variable
    ``` bash
    TOKEN=<YOUR_TOKEN> # eb4b6b1883b4f00f85378d34a8018ab60cf025d6
    ```

8. move to this repo folder
    ``` bash
    cd berlin-mob-atlantis
    ```

9. Start Atlantis 
    ``` bash
    USERNAME=<YOUR_GITHUB_USERNAME> 
    HOSTNAME=github.com
    REPO_ALLOWLIST="${HOSTNAME}/cloudreach/berlin-mob-atlantis"
    atlantis server \
                --atlantis-url="$URL" \
                --gh-user="$USERNAME" \
                --gh-token="$TOKEN" \
                --gh-webhook-secret="$SECRET" \
                --gh-hostname="$HOSTNAME" \
                --repo-allowlist="$REPO_ALLOWLIST" \ 
                --log-level=debug
    ```
    and accept incoming connections

Further info https://www.runatlantis.io/guide

# Deploy atlantis on AWS Fargate
To deploy atlantis in sandbox account, we make use of the official atlantis module for terraform provided by AWS, with the approach ["As a part of an existing AWS infrastructure"](https://github.com/terraform-aws-modules/terraform-aws-atlantis#run-atlantis-as-a-part-of-an-existing-aws-infrastructure-use-existing-vpc)

In "infra/infra.tf" you will see how it is used, providing
- vpc_id, private subnets (app-subnets), and public subnets
- the route53 HZ in use to validate the certificate attached to the ALB
- github user and token in use for this atlantis poc, stored in SecretsManager with id "atlantisGithubCreds"; # we can remove the secret and store the token in SSM Parameter /atlantis/github/user/token  or another param in SSM, whose name can be provided to the module with `atlantis_github_user_token_ssm_parameter_name`



