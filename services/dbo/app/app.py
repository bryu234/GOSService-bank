from __future__ import annotations

import os
from functools import wraps

import ldap
import ldap.filter
from flask import Flask, abort, redirect, render_template_string, request, session, url_for

app = Flask(__name__)
app.secret_key = os.environ["DBO_SECRET_KEY"]

LDAP_URI = f"ldap://{os.environ['BANK_LDAP_IP']}:{os.environ['LDAP_PORT']}"
LDAP_BASE_DN = os.environ["LDAP_BASE_DN"]

PAGE = """
<!doctype html><html lang=ru><meta charset=utf-8><title>Виртуальный банк — ДБО</title>
<style>body{font:16px system-ui;max-width:780px;margin:3rem auto;padding:0 1rem}nav a{margin-right:1rem}.box{padding:1rem;border:1px solid #bbb;border-radius:8px}button,input{padding:.55rem;margin:.25rem}</style>
<nav><a href='/'>Главная</a><a href='/payment'>Платёж</a><a href='/admin'>Администрирование</a><a href='/logout'>Выход</a></nav>
<h1>{{ title }}</h1><div class=box>{{ body|safe }}</div></html>
"""


def authenticate(username: str, password: str) -> set[str] | None:
    connection = ldap.initialize(LDAP_URI)
    connection.set_option(ldap.OPT_NETWORK_TIMEOUT, 5)
    try:
        connection.simple_bind_s(os.environ["LDAP_BIND_DN"], os.environ["LDAP_BIND_PASSWORD"])
        escaped_user = ldap.filter.escape_filter_chars(username)
        users = connection.search_s(
            LDAP_BASE_DN, ldap.SCOPE_SUBTREE, f"(uid={escaped_user})", ["dn"]
        )
        if len(users) != 1:
            return None
        resolved_dn = users[0][0]
        connection.simple_bind_s(resolved_dn, password)
        result = connection.search_s(
            f"ou=Groups,{LDAP_BASE_DN}", ldap.SCOPE_ONELEVEL,
            f"(member={ldap.filter.escape_filter_chars(resolved_dn)})", ["cn"]
        )
        return {attrs["cn"][0].decode() for _, attrs in result if attrs.get("cn")}
    except ldap.LDAPError:
        return None
    finally:
        connection.unbind_s()


def login_required(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        if "username" not in session:
            return redirect(url_for("login"))
        return function(*args, **kwargs)
    return wrapped


def require(permission: str):
    def decorator(function):
        @wraps(function)
        @login_required
        def wrapped(*args, **kwargs):
            if permission not in set(session.get("groups", [])):
                abort(403)
            return function(*args, **kwargs)
        return wrapped
    return decorator


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    if request.method == "POST":
        username = request.form.get("username", "")
        groups = authenticate(username, request.form.get("password", ""))
        if groups is not None and groups.intersection({"dbo_read", "dbo_write", "dbo_admin"}):
            session.update(username=username, groups=sorted(groups))
            return redirect(url_for("index"))
        else:
            error = "Неверные учетные данные или отсутствует роль ДБО"
    return render_template_string(PAGE, title="Вход в ДБО", body=f"<p>{error}</p><form method=post><input name=username placeholder=Логин><input name=password type=password placeholder=Пароль><button>Войти</button></form>")


@app.get("/")
@require("dbo_read")
def index():
    return render_template_string(PAGE, title="ДБО", body=f"Пользователь: {session['username']}<br>LDAP-группы: {', '.join(session['groups'])}")


@app.route("/payment", methods=["GET", "POST"])
@require("dbo_write")
def payment():
    message = "Учебный платёж доступен роли dbo_write."
    if request.method == "POST":
        message = "Учебный платёж принят."
    return render_template_string(PAGE, title="Платёж", body=f"<p>{message}</p><form method=post><button>Создать платёж</button></form>")


@app.get("/admin")
@require("dbo_admin")
def admin():
    return render_template_string(PAGE, title="Администрирование ДБО", body="Доступ разрешён роли dbo_admin.")


@app.get("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))
