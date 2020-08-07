# Web-app Dockerfile with secure
FROM python:3-alpine
MAINTAINER Ufkun KARAMAN <ufkunkaraman@gmail.com> 

# Create user with minimal permission
# Define argument 
ARG USER=hepsiburada

# Install sudo as root
RUN apk add --update sudo

#Add new user
RUN adduser -D $USER \
        && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
        && chmod 0440 /etc/sudoers.d/$USER
# User change
USER $USER

# Python add libraries
COPY ./requirements.txt $HOME/requirements.txt
RUN pip install -r $HOME/requirements.txt

# Python code copy 
COPY app.py $HOME/

# Delete sudo for security
RUN apk del sudo


# Expose the Flask port
EXPOSE 11130

CMD [ "python", "./app.py" ]
