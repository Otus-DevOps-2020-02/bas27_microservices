FROM alpine

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/

RUN apk --no-cache update &&\
    apk add ruby-full &&\
    apk add ruby-dev &&\
    apk add build-base &&\
    gem install bundler:1.17.2 --no-document &&\
    bundle install &&\
    apk del build-base

COPY . $APP_HOME

ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
