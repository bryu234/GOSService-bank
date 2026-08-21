from os import environ
from pathlib import Path

import ldap
from django.contrib.messages import constants as messages
from django_auth_ldap.config import LDAPSearch, GroupOfNamesType

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = environ["ABS_DJANGO_SECRET"]
DEBUG = False
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "bank.apps.BankConfig", "django.contrib.admin", "django.contrib.auth",
    "django.contrib.contenttypes", "django.contrib.sessions", "django.contrib.messages", "django.contrib.staticfiles",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware", "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware", "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware", "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware", "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "bac.banklab_middleware.BankLabRoleMiddleware",
]
ROOT_URLCONF = "bac.urls"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates", "DIRS": [], "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.request", "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
    ]},
}]
WSGI_APPLICATION = "bac.wsgi.application"

DATABASES = {"default": {
    "ENGINE": "django.db.backends.postgresql",
    "NAME": environ["ABS_DB_NAME"], "USER": environ["ABS_DB_USER"], "PASSWORD": environ["ABS_DB_PASSWORD"],
    "HOST": environ["BANK_ABS_DB_IP"], "PORT": environ["ABS_DB_PORT"],
}}

AUTHENTICATION_BACKENDS = ["django_auth_ldap.backend.LDAPBackend"]
AUTH_LDAP_SERVER_URI = f"ldap://{environ['BANK_LDAP_IP']}:{environ['LDAP_PORT']}"
AUTH_LDAP_BIND_DN = environ["LDAP_BIND_DN"]
AUTH_LDAP_BIND_PASSWORD = environ["LDAP_BIND_PASSWORD"]
AUTH_LDAP_USER_SEARCH = LDAPSearch(environ["LDAP_BASE_DN"], ldap.SCOPE_SUBTREE, "(uid=%(user)s)")
AUTH_LDAP_GROUP_SEARCH = LDAPSearch(f"ou=Groups,{environ['LDAP_BASE_DN']}", ldap.SCOPE_ONELEVEL, "(objectClass=groupOfNames)")
AUTH_LDAP_GROUP_TYPE = GroupOfNamesType()
AUTH_LDAP_MIRROR_GROUPS = True
AUTH_LDAP_ALWAYS_UPDATE_USER = True
AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    "is_staff": f"cn=abs_admin,ou=Groups,{environ['LDAP_BASE_DN']}",
    "is_superuser": f"cn=abs_admin,ou=Groups,{environ['LDAP_BASE_DN']}",
}

AUTH_PASSWORD_VALIDATORS = []
LANGUAGE_CODE = "ru-ru"
TIME_ZONE = environ.get("TZ", "Etc/UTC")
USE_I18N = True
USE_TZ = True
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
LOGIN_URL = "/sign-in"
MESSAGE_TAGS = {messages.ERROR: "", 50: "danger"}
FLAG_USER_NAME = "Training Beneficiary"
FLAG_USER_ACCOUNT = 424242
FLAG = "BANKLAB"
INITIAL_DEPOSIT = environ.get("ABS_INITIAL_DEPOSIT", "1000000")
PYTHON_BANK_NAME = "Virtual Bank"
