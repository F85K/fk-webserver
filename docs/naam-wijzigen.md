# Naam wijzigen in MongoDB

Deze instructies tonen hoe je de naam in de database kan aanpassen.

## Lokaal (Docker Compose)

````bash
# Ga in de MongoDB container
docker exec -it fk-mongo mongosh

# Switch naar database
use fkdb

# Update naam
db.profile.updateOne({key: "name"}, {$set: {value: "Nieuwe Naam"}})

# Exit
exit
````

Na de update, refresh http://localhost:8080 en de nieuwe naam verschijnt.

## Kubernetes

````bash
# Vind de MongoDB pod
kubectl get pods -n fk-webstack

# Ga in de pod (vervang POD_NAME)
kubectl exec -it POD_NAME -n fk-webstack -- mongosh

# Switch naar database
use fkdb

# Update naam
db.profile.updateOne({key: "name"}, {$set: {value: "Nieuwe Naam"}})

# Exit
exit
````
