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

## Risques et ameliorations

| Risque | Mitigation initiale | Extension possible |
| --- | --- | --- |
| Cout inattendu | Budget AWS et tags | budget IaC + alertes SNS |
| API publique | Validation stricte | Cognito + authorizer |
| Erreurs non detectees | Logs CloudWatch | alarmes + dashboards |
| Suppression accidentelle | Deletion protection logique | backups DynamoDB/PITR |

