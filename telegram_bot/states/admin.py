from __future__ import annotations

from aiogram.fsm.state import State, StatesGroup


class AddClientStates(StatesGroup):
    waiting_name = State()
    waiting_server = State()
    waiting_duration = State()
    confirm = State()
