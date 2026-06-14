# Observabilite

## Definitions simples

**Observabilite** signifie : etre capable de comprendre ce qui se passe dans ton systeme quand il fonctionne, ralentit ou echoue.

**CloudWatch** est le service AWS utilise pour centraliser des logs, suivre des metriques et creer des alarmes.

**Log group** est un conteneur CloudWatch pour des logs. Dans ce projet, Lambda utilise son log group automatique et API Gateway utilise un log group cree par Terraform.

**Retention** est la duree pendant laquelle AWS garde les logs. Une retention courte en `dev`, par exemple 14 jours, limite les couts.

**Metric alarm** est une alarme basee sur une metrique. Exemple : si la metrique `Errors` de Lambda est superieure ou egale a 1 sur 5 minutes, l'alarme passe en etat `ALARM`.

**SNS topic** est un canal de notification AWS. Ici, il peut envoyer un email quand une alarme se declenche.

**SNS subscription** est l'abonnement a un topic. Dans ce projet, la subscription est ton adresse email.

**Pending confirmation** signifie que SNS attend que tu cliques sur le lien recu par email. Tant que ce n'est pas confirme, SNS ne livre pas les alertes a cette adresse.

## Ce que Terraform ajoute

- Logs Lambda : `/aws/lambda/incidentops-dev-incidents-api`
- Logs API Gateway : `/aws/apigateway/incidentops-dev-api-access-<suffix>`
- Alarme Lambda : `incidentops-dev-lambda-errors`
- Alarme API : `incidentops-dev-api-5xx`
- SNS topic optionnel si `alarm_email` est defini

## Activer les notifications email

Dans `terraform.tfvars` :

```hcl
alarm_email = "ton-email@example.com"
```

Puis :

```powershell
cd infra/terraform/environments/dev
terraform plan
terraform apply
```

AWS enverra un email de confirmation SNS. Il faut cliquer sur le lien de confirmation, sinon les alertes ne seront pas livrees.

Flux complet :

```text
CloudWatch Alarm -> SNS Topic -> Email Subscription -> Ta boite mail
```

CloudWatch ne t'envoie pas l'email directement. Il publie un message dans SNS, puis SNS le livre a ton email.

Verifier la subscription :

```powershell
$topic = terraform output -raw alarm_topic_arn
aws sns list-subscriptions-by-topic --region eu-west-1 --topic-arn $topic
```

Dans la sortie, regarde `SubscriptionArn` :

- si la valeur est `PendingConfirmation`, il faut confirmer l'email SNS ;
- si la valeur ressemble a un ARN AWS, l'abonnement est confirme.

Tester l'email sans casser l'application :

```powershell
aws cloudwatch set-alarm-state `
  --region eu-west-1 `
  --alarm-name "incidentops-dev-lambda-errors" `
  --state-value ALARM `
  --state-reason "Manual email notification test"

aws cloudwatch set-alarm-state `
  --region eu-west-1 `
  --alarm-name "incidentops-dev-lambda-errors" `
  --state-value OK `
  --state-reason "Manual reset after email notification test"
```

Tu devrais recevoir un email pour le passage en `ALARM`, puis parfois un second pour le retour en `OK`, car le projet configure `alarm_actions` et `ok_actions`.

## Tester apres deploiement

Recupere les outputs :

```powershell
terraform output
```

Teste l'API :

```powershell
$api = terraform output -raw api_url
Invoke-RestMethod "$api/incidents"
```

Ensuite, dans la console AWS :

- va dans CloudWatch ;
- ouvre **Log groups** ;
- cherche les noms sortis par `lambda_log_group_name` et `api_access_log_group_name` ;
- ouvre **Alarms** pour voir `incidentops-dev-lambda-errors` et `incidentops-dev-api-5xx`.

## Depannage

### Log group deja existant

Si Terraform affiche :

```text
ResourceAlreadyExistsException: The specified log group already exists
```

cela veut dire qu'un log group avec le meme nom existe deja avant que Terraform ne le cree.

**Terraform state** est le fichier dans lequel Terraform garde la liste des ressources qu'il controle. Si une ressource existe dans AWS mais pas dans le state, Terraform pense qu'il doit la creer.

La solution classique est d'importer le log group existant dans le state :

```powershell
cd infra/terraform/environments/dev
terraform import aws_cloudwatch_log_group.lambda_api /aws/lambda/incidentops-dev-incidents-api
terraform plan
terraform apply
```

Apres l'import, Terraform ne cree plus ce log group. Il le gere, par exemple pour appliquer la retention `log_retention_days`.

Dans ce projet, on evite maintenant ce probleme pour Lambda : Terraform ne cree plus le log group Lambda. AWS Lambda le cree automatiquement au premier appel de la fonction.

### La console CloudWatch affiche 0 log groups

Si Terraform dit que le log group existe mais que la console affiche `Log groups (0)`, verifie d'abord ces trois points :

1. **Region AWS** : la console doit etre sur `eu-west-1`, aussi appelee **Ireland**.
2. **Compte AWS** : la console doit etre connectee au meme compte que ton AWS CLI.
3. **Filtre de recherche** : retire le mode `Exact match` ou vide tous les filtres.

Commandes utiles :

```powershell
aws sts get-caller-identity
aws configure get region
aws logs describe-log-groups --region eu-west-1 --log-group-name-prefix "/aws/lambda/incidentops-dev"
aws logs describe-log-groups --region eu-west-1 --log-group-name-prefix "/aws/apigateway/incidentops-dev"
```

**Region** signifie l'emplacement AWS ou les ressources sont creees. Une Lambda en `eu-west-1` n'apparaitra pas dans CloudWatch `us-east-1`.

**Account ID** est l'identifiant numerique de ton compte AWS. Si le CLI et la console ne pointent pas vers le meme compte, tu ne verras pas les memes ressources.

### Terraform dit up to date mais AWS CLI ne voit pas les log groups

Si `terraform state list` contient :

```text
aws_cloudwatch_log_group.lambda_api
aws_cloudwatch_log_group.api_access
```

mais que `aws logs describe-log-groups` retourne une liste vide, il faut comparer ce que Terraform a dans son state avec ce qu'AWS retourne.

Commandes de diagnostic :

```powershell
terraform state show aws_cloudwatch_log_group.lambda_api
terraform state show aws_cloudwatch_log_group.api_access
Get-ChildItem Env:AWS*
aws logs describe-log-groups --region eu-west-1
```

**State drift** signifie que le state Terraform ne correspond plus exactement a la realite AWS. Exemple : Terraform pense gerer une ressource, mais cette ressource n'existe plus ou se trouve dans un autre compte.

Si les log groups sont vraiment absents dans AWS mais presents dans le state, retire-les du state puis recree-les :

```powershell
terraform state rm aws_cloudwatch_log_group.lambda_api
terraform state rm aws_cloudwatch_log_group.api_access
terraform plan
terraform apply
```

`terraform state rm` ne supprime pas de ressource AWS. Il retire seulement la ressource de la memoire Terraform. Au prochain `apply`, Terraform essaiera donc de la creer.

Si la ressource `aws_cloudwatch_log_group.lambda_api` n'existe plus dans le code Terraform, c'est normal : le projet laisse maintenant Lambda creer ce log group automatiquement.

Si apres `terraform state rm`, `terraform apply` retourne encore `ResourceAlreadyExistsException`, cela confirme que la ressource existe bien dans AWS. Il faut alors l'importer :

```powershell
terraform import aws_cloudwatch_log_group.lambda_api /aws/lambda/incidentops-dev-incidents-api
terraform import aws_cloudwatch_log_group.api_access /aws/apigateway/incidentops-dev-api
terraform plan
terraform apply
```

Resume :

- `terraform state rm` : oublie une ressource localement ;
- `terraform import` : rattache une ressource AWS existante au state Terraform ;
- `terraform apply` : cree ou modifie ce qui manque vraiment.
