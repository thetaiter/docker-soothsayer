FROM node:argon
MAINTAINER Ian Tait <itait@us.ibm.com>

RUN mkdir /src

WORKDIR /src

COPY ./package.json /src/package.json

RUN npm install

COPY ./app.js /src/app.js

EXPOSE 3000

CMD ["node", "app.js"]
