FROM swift:4.2 as builder

WORKDIR /opt/OtaDeployState

COPY LICENSE .
COPY README.md .
COPY Tests ./Tests
COPY Package.swift .
COPY Package.resolved .
COPY Sources ./Sources

RUN swift build -c release

FROM swift:4.2

WORKDIR /opt/OtaDeployState
COPY --from=builder /opt/OtaDeployState/.build/release/OtaDeployState ./.build/release/OtaDeployState


RUN mkdir -p /usr/local/opt/ota-deploy-state/

CMD ./.build/release/OtaDeployState
