# Runbook de test

Ce runbook sert a verifier rapidement que l'application fonctionne dans la region `eu-west-1`.

## Definitions

**Runbook** : liste de commandes reproductibles pour diagnostiquer ou tester un systeme.

**Endpoint API** : URL publique exposee par API Gateway.

**Log group** : conteneur CloudWatch qui regroupe les logs d'un service.

**Region** : emplacement AWS ou les ressources sont creees. Ce projet utilise `eu-west-1` (Ireland).

## 1. Verifier Terraform

```powershell
cd infra/terraform/environments/dev
terraform validate
terraform output
```

## 2. Verifier que les ressources existent

```powershell
aws sts get-caller-identity
aws lambda list-functions --region eu-west-1 --query "Functions[?contains(FunctionName, 'incidentops')].FunctionName"
aws apigatewayv2 get-apis --region eu-west-1 --query "Items[?contains(Name, 'incidentops')].[Name,ApiEndpoint]"
aws dynamodb list-tables --region eu-west-1
```

## 3. Tester l'API

```powershell
$api = terraform output -raw api_url
Invoke-RestMethod "$api/incidents"

Invoke-RestMethod "$api/incidents" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"title":"Runbook test","severity":"medium"}'

Invoke-RestMethod "$api/incidents"
```

## 4. Lire les logs

```powershell
aws logs describe-log-groups --region eu-west-1 --log-group-name-prefix "/aws/lambda/incidentops-dev"
aws logs tail "/aws/lambda/incidentops-dev-incidents-api" --region eu-west-1 --since 15m
```

Pour API Gateway :

```powershell
$apiLogs = terraform output -raw api_access_log_group_name
aws logs tail $apiLogs --region eu-west-1 --since 15m
```

## 5. Verifier les alarmes

```powershell
aws cloudwatch describe-alarms --region eu-west-1 --alarm-name-prefix "incidentops-dev"
```

Si `alarm_email` est configure, verifie la subscription SNS :

```powershell
$topic = terraform output -raw alarm_topic_arn
aws sns list-subscriptions-by-topic --region eu-west-1 --topic-arn $topic
```

**PendingConfirmation** signifie que tu dois ouvrir l'email envoye par AWS et confirmer l'abonnement.

Pour tester une alarme manuellement :

```powershell
aws cloudwatch set-alarm-state `
  --region eu-west-1 `
  --alarm-name "incidentops-dev-lambda-errors" `
  --state-value ALARM `
  --state-reason "Manual runbook test"

aws cloudwatch set-alarm-state `
  --region eu-west-1 `
  --alarm-name "incidentops-dev-lambda-errors" `
  --state-value OK `
  --state-reason "Manual reset"
```
