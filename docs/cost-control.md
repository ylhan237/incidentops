# Controle des couts

Avant de deployer, mets en place un budget AWS. AWS Budgets permet de suivre les couts et d'envoyer des alertes quand les depenses reelles ou prevues approchent un seuil.

Budget conseille pour le projet :

- type : monthly cost budget ;
- seuil bas : notification a 50% ;
- seuil haut : notification a 80% ;
- email : ton adresse principale ;
- tags : `Project=incidentops-serverless-hub`, `Environment=dev`.

Notes :

- Les notifications de budget peuvent avoir du delai, donc elles ne remplacent pas une verification reguliere de la console Billing.
- Detruis les ressources de test avec `terraform destroy` quand tu n'en as plus besoin.
- Evite d'activer des services non prevus dans la roadmap.

