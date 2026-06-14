# GitLab CI/CD

## Objectif

Le pipeline GitLab commence simple :

- validation Python ;
- verification du format Terraform ;
- validation Terraform ;
- plan Terraform manuel ;
- deploiement frontend manuel vers S3 + invalidation CloudFront.

L'`apply` automatique est volontairement laisse de cote au debut. Pour un projet portfolio, c'est plus propre de montrer que l'infrastructure est revue avant creation, surtout tant que le backend Terraform distant et l'authentification OIDC GitLab ne sont pas encore en place.

## Variables GitLab a creer

Dans GitLab : **Settings > CI/CD > Variables**.

Variables minimales :

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` avec la valeur `us-east-1`
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

## Prochaine amelioration

Remplacer les access keys par GitLab OIDC + un role IAM AWS limite au projet. C'est une excellente extension portfolio, car elle montre une approche plus securisee que des cles longues durees.

