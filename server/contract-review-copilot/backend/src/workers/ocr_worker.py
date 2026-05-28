from __future__ import annotations

import asyncio
import time
import traceback
from asyncio import to_thread

from ..ocr import ingest_contract_files
from ..ocr.task_storage import cleanup_staged_ocr_task_files, load_staged_ocr_task_files
from ..services import queue_service, sync_store

OCR_TASK_CANCELLED_MESSAGE = "OCR 任务已取消。"
OCR_TASK_FAILURE_MESSAGE = "合同材料识别失败，请稍后重试。"
OCR_TASK_RETRYING_MESSAGE = "OCR 识别异常，正在准备自动重试。"


async def run_queued_ocr(
    task_id: str,
    *,
    max_retries: int = 0,
    retry_backoff_seconds: float = 1.5,
) -> None:
    attempt = 0

    while True:
        attempt += 1
        queue_service.update_task_status(
            task_id,
            "running",
            task_type="ocr",
            attempt=attempt,
            retry_count=attempt - 1,
            progress_message="任务已进入 OCR 队列。",
            next_retry_at=None,
            last_error=None,
            error_code=None,
            dead_letter=False,
        )

        try:
            files = await to_thread(load_staged_ocr_task_files, task_id)
            queue_service.update_task_status(
                task_id,
                "running",
                task_type="ocr",
                attempt=attempt,
                retry_count=attempt - 1,
                file_count=len(files),
                progress_message="正在识别合同内容…",
                next_retry_at=None,
            )
            result = await to_thread(ingest_contract_files, files)
            task = queue_service.get_task(task_id, task_type="ocr") or {}
            document = sync_store.create_document(
                user_id=str(task.get("user_id") or ""),
                filename=result.display_name,
                content_text=result.merged_text,
                source_type=result.source_type,
                warnings=result.warnings,
                status="ocr_ready",
            ) if task.get("user_id") else None
            await to_thread(cleanup_staged_ocr_task_files, task_id)
            queue_service.update_task_status(
                task_id,
                "completed",
                task_type="ocr",
                retry_count=attempt - 1,
                result={**result.to_dict(), **({"document_id": document["id"]} if document else {})},
                progress_message="合同材料识别完成。",
                next_retry_at=None,
                last_error=None,
                error_code=None,
                dead_letter=False,
            )
            return

        except asyncio.CancelledError:
            await to_thread(cleanup_staged_ocr_task_files, task_id)
            queue_service.update_task_status(
                task_id,
                "cancelled",
                task_type="ocr",
                retry_count=max(0, attempt - 1),
                last_error=OCR_TASK_CANCELLED_MESSAGE,
                error_code="OCR_TASK_CANCELLED",
                progress_message=OCR_TASK_CANCELLED_MESSAGE,
                next_retry_at=None,
                dead_letter=False,
            )
            raise

        except ValueError as exc:
            await to_thread(cleanup_staged_ocr_task_files, task_id)
            queue_service.update_task_status(
                task_id,
                "failed",
                task_type="ocr",
                retry_count=attempt - 1,
                last_error=str(exc),
                error_code="INGEST_VALIDATION_ERROR",
                progress_message="合同材料校验失败。",
                next_retry_at=None,
                dead_letter=False,
            )
            return

        except Exception as exc:
            print(f"[OCRWorker] Task {task_id} failed on attempt {attempt}: {exc}", flush=True)
            traceback.print_exc()
            if attempt <= max_retries:
                delay_seconds = max(retry_backoff_seconds, 0.1) * attempt
                queue_service.update_task_status(
                    task_id,
                    "retrying",
                    task_type="ocr",
                    retry_count=attempt,
                    last_error=OCR_TASK_RETRYING_MESSAGE,
                    error_code="OCR_TASK_RETRYING",
                    progress_message=OCR_TASK_RETRYING_MESSAGE,
                    next_retry_at=time.time() + delay_seconds,
                    dead_letter=False,
                )
                await asyncio.sleep(delay_seconds)
                continue

            await to_thread(cleanup_staged_ocr_task_files, task_id)
            queue_service.update_task_status(
                task_id,
                "dead_letter",
                task_type="ocr",
                retry_count=attempt - 1,
                last_error=OCR_TASK_FAILURE_MESSAGE,
                error_code="OCR_TASK_FAILED",
                progress_message=OCR_TASK_FAILURE_MESSAGE,
                next_retry_at=None,
                dead_letter=True,
            )
            return
