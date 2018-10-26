FROM swift:4.2

WORKDIR /opt/OtaDeployState
COPY . .

RUN swift build
