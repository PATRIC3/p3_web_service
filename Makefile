TOP_DIR = ../..
DEPLOY_RUNTIME ?= /disks/patric-common/runtime
TARGET ?= /tmp/deployment
include $(TOP_DIR)/tools/Makefile.common

SERVICE_SPEC = 
SERVICE_NAME = p3_web_service
SERVICE_HOSTNAME = localhost
SERVICE_PORT = 3000
SERVICE_DIR  = $(SERVICE_NAME)
SERVICE_APP_DIR      = $(TARGET)/services/$(SERVICE_DIR)/app

USER_SERVICE_PORT = 3002

#APP_REPO     = https://github.com/PATRIC3/p3_web.git
APP_REPO     = https://github.com/olsonanl/p3_web.git
#APP_TAG	     = -b build.fix
APP_DIR      = p3_web
APP_SCRIPT   = ./bin/p3-web

PATH := $(DEPLOY_RUNTIME)/build-tools/bin:$(PATH)

CONFIG          = p3-web.conf
CONFIG_TEMPLATE = $(CONFIG).tt

PRODUCTION = true
REDIS_HOST = beech.mcs.anl.gov
REDIS_PORT = 6379
REDIS_DB   = 1
REDIS_PREFIX = 
REDIS_PASS = 
SITE_URL = http://$(SERVICE_HOSTNAME):$(SERVICE_PORT)
P3_HOME_URL = 
CALLBACK_URL = $(SITE_URL)/auth/callback
ACCOUNT_URL = http://$(SERVICE_HOSTNAME):$(USER_SERVICE_PORT)
AUTHORIZATION_URL = "$(ACCOUNT_URL)/login"
COOKIE_SECRET = patric3
COOKIE_KEY = patric3
COOKIE_DOMAIN = $(shell echo $(SERVICE_HOSTNAME) | sed -e 's/^[^.][^.]*\././') 

DATA_API_URL = http://$(SERVICE_HOSTNAME):3001
WORKSPACE_SERVICE_URL = https://p3.theseed.org/services/Workspace
APP_SERVICE_URL = https://p3.theseed.org/services/app_service
HOMOLOGY_SERVICE_URL =
APP_LABEL = 
NEWRELIC_LICENSE_KEY = 
GOOGLE_ANALYTICS_ID = 
ENABLE_DEV_AUTH = false
ENABLE_DEV_TOOLS = false
EMAIL_LOCAL_SENDMAIL = true
EMAIL_DEFAULT_FROM = "PATRIC <do-not-reply@patricbrc.org>"
EMAIL_DEFAULT_SENDER = "PATRIC <do-not-reply@patricbrc.org>"
EMAIL_HOST = 
EMAIL_PORT = 25
EMAIL_USERNAME =
EMAIL_PASSWORD =

SERVICE_PSGI = $(SERVICE_NAME).psgi
TPAGE_ARGS = --define kb_runas_user=$(SERVICE_USER) \
	--define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE_NAME) \
	--define kb_service_dir=$(SERVICE_DIR) \
	--define kb_service_port=$(SERVICE_PORT) \
	--define kb_psgi=$(SERVICE_PSGI) \
	--define kb_app_dir=$(SERVICE_APP_DIR) \
	--define kb_app_script=$(APP_SCRIPT) \
	--define production=$(PRODUCTION) \
	--define redis_host=$(REDIS_HOST) \
	--define redis_port=$(REDIS_PORT) \
	--define redis_db=$(REDIS_DB) \
	--define redis_prefix=$(REDIS_PREFIX) \
	--define redis_pass=$(REDIS_PASS) \
	--define site_url=$(SITE_URL) \
	--define p3_home_url=$(P3_HOME_URL) \
	--define account_url=$(ACCOUNT_URL) \
	--define authorization_url=$(AUTHORIZATION_URL) \
	--define cookie_secret=$(COOKIE_SECRET) \
	--define cookie_key=$(COOKIE_KEY) \
	--define cookie_domain=$(COOKIE_DOMAIN) \
	--define data_api_url=$(DATA_API_URL) \
	--define workspace_service_url=$(WORKSPACE_SERVICE_URL) \
	--define app_service_url=$(APP_SERVICE_URL) \
	--define homology_service_url=$(HOMOLOGY_SERVICE_URL) \
	--define app_label=$(APP_LABEL) \
	--define newrelic_license_key=$(NEWRELIC_LICENSE_KEY) \
	--define google_analytics_id=$(GOOGLE_ANALYTICS_ID) \
	--define enable_dev_auth=$(ENABLE_DEV_AUTH) \
	--define enable_dev_tools=$(ENABLE_DEV_TOOLS) \
	--define email_local_sendmail=$(EMAIL_LOCAL_SENDMAIL) \
	--define email_default_from=$(EMAIL_DEFAULT_FROM) \
	--define email_default_sender=$(EMAIL_DEFAULT_SENDER) \
	--define email_host=$(EMAIL_HOST) \
	--define email_port=$(EMAIL_PORT) \
	--define email_username=$(EMAIL_USERNAME) \
	--define email_password=$(EMAIL_PASSWORD)

# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
TOOLS_DIR = $(TOP_DIR)/tools
WRAP_PERL_TOOL = wrap_perl
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)


default: build-app build-config

build-app:
	if [ ! -f $(APP_DIR)/package.json ] ; then \
		git clone $(APP_TAG) --recursive $(APP_REPO) $(APP_DIR); \
	fi
	cd $(APP_DIR); npm install grunt
	cd $(APP_DIR); npm install
	cd $(APP_DIR); npm install forever
	cd $(APP_DIR); ./buildClient.sh

dist: 

test: 

deploy: deploy-client deploy-service

deploy-all: deploy-client deploy-service

deploy-client: 

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done

deploy-service: deploy-run-scripts deploy-app deploy-config

deploy-app: build-app
	-mkdir -p $(SERVICE_APP_DIR)
	rsync --exclude .git --delete -arv $(APP_DIR)/. $(SERVICE_APP_DIR)

deploy-config: build-config
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(SERVICE_APP_DIR)/$(CONFIG)

build-config:
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(APP_DIR)/$(CONFIG)

deploy-run-scripts:
	mkdir -p $(TARGET)/services/$(SERVICE_DIR)
	for script in start_service stop_service postinstall; do \
		$(TPAGE) $(TPAGE_ARGS) service/$$script.tt > $(TARGET)/services/$(SERVICE_NAME)/$$script ; \
		chmod +x $(TARGET)/services/$(SERVICE_NAME)/$$script ; \
	done
	mkdir -p $(TARGET)/postinstall
	rm -f $(TARGET)/postinstall/$(SERVICE_NAME)
	ln -s ../services/$(SERVICE_NAME)/postinstall $(TARGET)/postinstall/$(SERVICE_NAME)

deploy-upstart: deploy-service
	-cp service/$(SERVICE_NAME).conf /etc/init/
	echo "done executing deploy-upstart target"

deploy-cfg:

deploy-docs:
	-mkdir -p $(TARGET)/services/$(SERVICE_DIR)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_DIR)/webroot/.


build-libs:

include $(TOP_DIR)/tools/Makefile.common.rules
