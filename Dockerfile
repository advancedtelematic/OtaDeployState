FROM swift:4.2

WORKDIR /opt/OtaDeployState

COPY README.md .
COPY Tests ./Tests
COPY Package.swift .
COPY Package.resolved .
COPY Sources ./Sources

RUN swift build -c release

CMD ./.build/release/OtaDeployState
