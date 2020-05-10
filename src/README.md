# Micorservices

docker pull mongo:latest
docker build -t <your-dockerhub-login>/post:1.0 ./post-py
docker build -t <your-dockerhub-login>/comment:1.0 ./comment
docker build -t <your-dockerhub-login>/ui:1.0 ./ui

docker network create reddit

docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest &&\
docker run -d --network=reddit --network-alias=post bas27/post:1.0 &&\
docker run -d --network=reddit --network-alias=comment bas27/comment:1.0 &&\
docker run -d --network=reddit -p 9292:9292 bas27/ui:1.0

docker kill $(docker ps -q)

используем другие алиасы при запуске
docker run -d --network=reddit --network-alias=posts --network-alias=comments mongo:latest &&\
docker run -d --network=reddit --network-alias=post bas27/post:1.0 &&\
docker run -d --network=reddit --network-alias=comment bas27/comment:1.0 &&\
docker run -d --network=reddit -p 9292:9292 bas27/ui:1.0
