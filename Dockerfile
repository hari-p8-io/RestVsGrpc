FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/rest-grpc-camel-service-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8080 6565
ENTRYPOINT ["java", "-jar", "app.jar"]
