from __future__ import annotations

from aiogram import F, Router
from aiogram.filters import StateFilter
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from keyboards.client import back_to_main_kb, cancel_kb
from services.panel_api import PanelAPIError, panel_api
from states.auth import AiStates

router = Router(name="client.ai")

INTRO = (
    "🤖 <b>AI-помощник</b>\n\n"
    "Опишите вашу проблему с подключением или вопрос по выбору протокола — "
    "я передам его ИИ-ассистенту панели.\n\n"
    "<i>Например: «не подключается с Китая, что выбрать?»</i>"
)


@router.callback_query(F.data == "menu:ai")
async def cb_ai(callback: CallbackQuery, state: FSMContext) -> None:
    await state.clear()
    await callback.message.answer(INTRO, reply_markup=cancel_kb())
    await state.set_state(AiStates.waiting_question)
    await callback.answer()


@router.message(StateFilter(AiStates.waiting_question))
async def on_question(message: Message, state: FSMContext) -> None:
    question = (message.text or "").strip()
    await state.clear()

    if not question:
        await message.answer("⚠ Пустой вопрос. Попробуйте снова.", reply_markup=back_to_main_kb())
        return

    notice = await message.answer("🤖 Думаю, подождите…")

    try:
        result = await panel_api.ai_assist(question)
    except PanelAPIError as exc:
        await notice.edit_text(f"❌ {exc.message}", reply_markup=back_to_main_kb())
        return

    answer = (
        result.get("message")
        or result.get("result")
        or result.get("answer")
        or "⚠ Ответ не получен. Попробуйте переформулировать вопрос."
    )
    if not isinstance(answer, str):
        answer = str(answer)

    await notice.delete()
    await message.answer(f"🤖 <b>AI-ответ:</b>\n\n{answer}", reply_markup=back_to_main_kb())
