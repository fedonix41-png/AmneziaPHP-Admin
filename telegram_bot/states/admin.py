from __future__ import annotations

from aiogram.fsm.state import State, StatesGroup


class AddClientStates(StatesGroup):
    waiting_name = State()
    waiting_server = State()
    waiting_duration = State()
    confirm = State()


class AddServerStates(StatesGroup):
    waiting_name = State()
    waiting_host = State()
    waiting_port = State()
    waiting_username = State()
    waiting_password = State()

