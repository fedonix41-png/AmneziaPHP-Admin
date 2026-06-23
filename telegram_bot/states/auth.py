from __future__ import annotations

from aiogram.fsm.state import State, StatesGroup


class AuthStates(StatesGroup):
    waiting_email = State()
    waiting_password = State()


class AiStates(StatesGroup):
    waiting_question = State()
