VERSION=0.0.1
BUILD=`date +%FT%T%z`
PROJECT_HOME=$(shell pwd)

help:
	@bash build.sh -h

linux-amd64:
	GOARCH=amd64 GOOS=linux go build -o ttrpc-parser main.go

linux-arm64:
	GOARCH=arm64 GOOS=linux go build -o ttrpc-parser main.go

mac-amd64:
	GOARCH=amd64 GOOS=darwin go build -o ttrpc-parser main.go

mac-arm64:
	GOARCH=arm64 GOOS=darwin go build -o ttrpc-parser main.go

clean:
	rm -rf ttrpc-parser

.PHONY: linux mac cllean
