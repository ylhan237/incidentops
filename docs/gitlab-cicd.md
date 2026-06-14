# GitLab CI/CD

## Objectif

Le pipeline GitLab commence simple :

- validation Python ;
- verification du format Terraform ;
- validation Terraform ;
- plan Terraform manuel ;
- deploiement frontend manuel vers S3 + invalidation CloudFront.

L'`apply` automatique est volontairement laisse de cote au debut. Pour un projet portfolio, c'est plus propre de montrer que l'infrastructure est revue avant creation, surtout tant que le backend Terraform distant n'est pas encore en place.

## Variables GitLab a creer

Dans GitLab : **Settings > CI/CD > Variables**.

Variables minimales :

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` avec la valeur `eu-west-1`
- `INCIDENTOPS_API_URL`
- `SITE_BUCKET_NAME`
- `CLOUDFRONT_DISTRIBUTION_ID`

Apres `terraform apply`, recupere les valeurs avec :

```powershell
cd infra/terraform/environments/dev
terraform output
```

Mapping :

- `api_url` -> `INCIDENTOPS_API_URL`
- `site_bucket_name` -> `SITE_BUCKET_NAME`
- `cloudfront_distribution_id` -> `CLOUDFRONT_DISTRIBUTION_ID`

## Option securisee : GitLab OIDC

GitLab OIDC evite les access keys longues durees. GitLab emet un ID token pour le job, puis AWS STS retourne des credentials temporaires avec `AssumeRoleWithWebIdentity`.

1. Trouve le chemin de ton projet GitLab, par exemple `mon-groupe/incidentops`.
2. Mets a jour `terraform.tfvars` :

```hcl
enable_gitlab_oidc   = true
gitlab_project_path  = "mon-groupe/incidentops"
gitlab_deploy_branch = "main"
```

3. Applique Terraform :

```powershell
cd infra/terraform/environments/dev
terraform plan
terraform apply
terraform output -raw gitlab_deploy_role_arn
```

4. Dans GitLab, ajoute la variable :

- `AWS_ROLE_ARN` avec la valeur de `gitlab_deploy_role_arn`

5. Relance `frontend:deploy`.

Quand `AWS_ROLE_ARN` existe, le job utilise OIDC. Sinon, il continue avec les access keys deja configurees.

Apres validation OIDC, supprime `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` des variables GitLab.
