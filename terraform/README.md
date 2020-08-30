```
cp  terraform.tfvars.sample  terraform.tfvars
```
edit variables

github variables are for repo where to find app code.


create oaauth token @ gthub  https://github.com/settings/tokens/new
you need only repo/public_repo scope

and configure github_oauth_token variable

run 
```
terraform init
terraform apply

```
