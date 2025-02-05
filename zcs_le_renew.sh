#!/bin/bash

# DESCRIPTION
# ------------------

#
# version 0.1alpha
#
# This script renews certificates and registers it on ZCS.
#

# TERMS OF USE
# ------------------

# 2021, blaz@overssh.si
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
# 
#  - The above copyright notice and this permission notice shall be included 
#    in all copies or substantial portions of the Software.
# 
#  - THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
#    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#    DEALINGS IN THE SOFTWARE.

DOMAINNAME=ssh-postoffice.overssh.si  # your domain (only for single domain at the moment
PREFFEREDCHAIN= "ISRG Root X1"        # don't touch
LETEMP=/opt/zimbra/ssl/le-new         # cert directory with zimbra user read permissions

# generate certificats
#certbot certonly --standalone --force-renewal --preferred-chain "$PREFERREDCHAIN" -d $DOMAINNAME

certbot certonly --preferred-chain="ISRG Root X1" --manual -d *.dominio.cu -d dominio.cu --agree-tos --no-bootstrap --manual-public-ip-logging-ok --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory

# create fullchain (copy first, then append)
cp /etc/letsencrypt/live/$DOMAINNAME/chain.pem /etc/letsencrypt/live/$DOMAINNAME/fullchain.pem 
# pipe rootcert to fullchain (only first time - still alpha version)
curl https://letsencrypt.org/certs/isrgrootx1.pem.txt >> /etc/letsencrypt/live/ssh-postoffice.overssh.si/fullchain.pem

# copy to zimbra dir; set permissions, so zimbra user would be able to read certificates
mkdir -p $LETEMP
yes | cp /etc/letsencrypt/live/$DOMAINNAME/* $LETEMP/
chmod 644 $LETEMP/*

# verify chain with zmcertmgr
runuser -u zimbra -- /opt/zimbra/bin/zmcertmgr verifycrt comm $LETEMP/privkey.pem $LETEMP/cert.pem $LETEMP/fullchain.pem
# do backup of old certificates
runuser -u zimbra -- cp -a /opt/zimbra/ssl/zimbra /opt/zimbra/ssl/zimbra.$(date +"%YYmYd")
# deploy certificates - private key
runuser -u zimbra -- yes | cp $LETEMP/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
# deploy chain
runuser -u zimbra -- /opt/zimbra/bin/zmcertmgr deploycrt comm $LETEMP/cert.pem $LETEMP/fullchain.pem
# restart zimbra services
runuser -u zimbra -- /opt/zimbra/bin/zmcontrol restart
