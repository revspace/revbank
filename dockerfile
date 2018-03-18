FROM perl:5.20
COPY . /usr/src/revbank
WORKDIR /usr/src/revbank
RUN cpanm -i Term::ReadLine::Gnu
CMD [ "perl", "./revbank"]
