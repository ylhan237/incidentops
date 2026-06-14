# Architecture

## But du systeme

IncidentOps Serverless Hub est une application de suivi d'incidents simple mais realiste. Elle permet de demontrer une architecture AWS moderne, peu couteuse, scalable et securisee par defaut.

## Composants

| Composant | Role | Concepts SAA revises |
| --- | --- | --- |
| Amazon S3 | Hebergement du frontend statique | stockage objet, chiffrement, blocage acces public |
| Amazon CloudFront | CDN et point d'entree web | cache, distribution globale, OAC |
| API Gateway HTTP API | Point d'entree API | integration Lambda, routes, CORS |
| AWS Lambda | Logique metier serverless | compute event-driven, IAM execution role |
| DynamoDB | Stockage des incidents | NoSQL, partition key, on-demand capacity |
| CloudWatch | Logs et monitoring | observabilite, troubleshooting |
| IAM | Permissions minimales | least privilege, roles, policies |

## Decisions d'architecture

### Frontend statique avec S3 + CloudFront

Le bucket S3 reste prive. CloudFront accede au contenu via Origin Access Control. Cela evite d'exposer directement le bucket et donne un point d'entree cacheable.

### API serverless

API Gateway et Lambda reduisent l'operationnel : pas de serveur a maintenir, facturation a l'usage, scaling automatique. Pour un projet portfolio et un trafic faible, c'est un bon compromis cout/simplicite.

### DynamoDB on-demand

Le mode `PAY_PER_REQUEST` evite de dimensionner la capacite au depart. C'est adapte a une application avec trafic incertain.

### IAM minimal

La Lambda a uniquement les droits necessaires pour lire et ecrire dans la table DynamoDB du projet. Les logs CloudWatch passent par la policy geree AWS de base pour Lambda.

### Observabilite avec CloudWatch

CloudWatch centralise les logs et les metriques AWS. Le projet utilise deux log groups :

- un log group Lambda cree automatiquement par AWS Lambda pour les logs d'execution ;
- un log group API Gateway cree par Terraform pour les logs d'acces HTTP.

La retention du log group API Gateway est limitee avec `log_retention_days` pour eviter de garder des logs inutilement longtemps et de payer pour de l'historique peu utile en environnement `dev`.

Deux alarmes CloudWatch surveillent les erreurs :

- `lambda_errors` surveille les erreurs de la fonction Lambda ;
- `api_5xx` surveille les erreurs serveur retournees par API Gateway.

Si `alarm_email` est renseigne, Terraform cree aussi un topic SNS. SNS signifie Simple Notification Service : c'est le service AWS qui envoie les notifications, ici par email.

## Risques et ameliorations

| Risque | Mitigation initiale | Extension possible |
| --- | --- | --- |
| Cout inattendu | Budget AWS et tags | budget IaC + alertes SNS |
| API publique | Validation stricte | Cognito + authorizer |
| Erreurs non detectees | Logs CloudWatch | alarmes + dashboards |
| Suppression accidentelle | Deletion protection logique | backups DynamoDB/PITR |
