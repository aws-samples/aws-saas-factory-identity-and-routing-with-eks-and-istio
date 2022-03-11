#!/usr/bin/bash
. ~/.bash_profile

    dig +noall +short +answer \
    $(kubectl -n istio-system get svc \
        --output jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}') \
    | awk '{printf "%s\ttenantc.example.com\n",$0}'