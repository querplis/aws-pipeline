```
git clone https://github.com/querplis/aws-pipeline.git \
&& cd aws-pipeline/terraform \
&& cp terraform.tfvars.sample  terraform.tfvars
```
edit variables

github variables are for repo with the app code and  appspec.yml, buildspec.yml

create oaauth token @ gthub  https://github.com/settings/tokens/new
you need only repo/public_repo scope

and configure github_oauth_token variable

run 
```
terraform init
terraform apply

```
sadly with the 
```
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
```
aws is copying asg and then removng old one, so unless we write some code to rename and/or import terraform objects we cant use this code to reconfigure all this stuff , only for deployment 
and for the same reason, dont forget to manualy remove auto scaling group when destroying.
