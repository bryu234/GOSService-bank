from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from bank.models import Bank, Product
from os import environ


class Command(BaseCommand):
    help = "Seed LDAP-backed users with stable demonstration bank accounts"

    def handle(self, *args, **options):
        bank, _ = Bank.objects.get_or_create(id=1, defaults={"name": "Virtual Bank"})
        # The shared service identity intentionally has the same broad START
        # access as operations/cashier and is part of the students' hardening
        # assignment.  It therefore needs a demonstrable account as well.
        users = [environ["OPER_USER"], environ["CASH_USER"], environ["IT_USER"], environ["SVC_SHARED_USER"]]
        for index, username in enumerate(users, start=1):
            user, _ = User.objects.get_or_create(username=username, defaults={"first_name": username})
            user.set_unusable_password()
            user.save(update_fields=["password"])
            Product.objects.get_or_create(number=420000 + index, defaults={"user": user, "bank": bank, "type": "CA"})
