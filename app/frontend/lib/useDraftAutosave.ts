import { useEffect, useRef, useState } from "react";
import { router } from "@inertiajs/react";
import type { DraftMetadata, InvoiceForm } from "../types";
import { DraftSaver, DraftSaveError } from "./draftSaver";
import type { DraftSaveState } from "./draftSaver";

export default function useDraftAutosave(
  data: InvoiceForm,
  draft: DraftMetadata | null,
  seasonId: number,
  invoiceId: number | null,
) {
  const [state, setState] = useState<DraftSaveState>({
    phase: "saved",
    metadata: draft ?? undefined,
  });
  const latest = useRef(data);
  latest.current = data;
  const alive = useRef(true);
  const navigation = useRef(false);
  const saver = useRef<DraftSaver | null>(null);
  const address = useRef(draft?.id ?? null);
  if (!saver.current) {
    saver.current = new DraftSaver(
      draft ?? {
        id: null,
        client_key: crypto.randomUUID(),
        lock_version: 0,
        season_id: seasonId,
        invoice_id: invoiceId,
      },
      data,
      async (identity, snapshot) => {
        const csrf =
          document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
            ?.content ?? "";
        const response = await fetch(
          identity.id ? `/invoice_drafts/${identity.id}` : "/invoice_drafts",
          {
            method: identity.id ? "PATCH" : "POST",
            credentials: "same-origin",
            headers: {
              "Content-Type": "application/json",
              Accept: "application/json",
              "X-CSRF-Token": csrf,
            },
            body: JSON.stringify({ ...identity, data: snapshot }),
          },
        );
        if (response.redirected)
          throw new DraftSaveError(
            "Your session expired. Sign in again in another tab, then retry saving.",
            401,
          );
        if (!response.headers.get("content-type")?.includes("application/json"))
          throw new DraftSaveError(
            "Couldn't save this draft. Keep this page open and retry.",
            response.status,
          );
        const result = (await response.json()) as DraftMetadata & {
          error?: string;
        };
        if (!response.ok)
          throw new DraftSaveError(
            result.error ??
              "Couldn't save. Your edits are still here; please retry.",
            response.status,
          );
        return result;
      },
      (next) => {
        if (!alive.current) return;
        setState((previous) => ({ ...previous, ...next }));
        if (next.metadata) {
          router.flushAll();
          if (address.current !== next.metadata.id) {
            address.current = next.metadata.id;
            router.replace({
              url: `/invoice_drafts/${next.metadata.id}/edit`,
              preserveState: true,
              preserveScroll: true,
            });
          }
        }
      },
    );
  }
  const flush = async (force = false) => {
    saver.current!.change(latest.current);
    return saver.current!.flush(force);
  };
  useEffect(() => {
    saver.current!.change(data);
    if (!saver.current!.dirty) return;
    setState((previous) =>
      previous.phase === "error" ? previous : { ...previous, phase: "waiting" },
    );
    const timeout = window.setTimeout(() => {
      void saver.current!.flush().catch(() => {});
    }, 700);
    return () => window.clearTimeout(timeout);
  }, [data]);
  useEffect(() => {
    alive.current = true;
    const remove = router.on("before", (event) => {
      const visit = event.detail.visit;
      if (
        visit.prefetch ||
        (visit.only.length > 0 &&
          visit.only.every((key) =>
            [
              "game_options",
              "game_detail",
              "contact_options",
              "matching_games",
            ].includes(key),
          ))
      )
        return;
      saver.current!.change(latest.current);
      if (!saver.current!.dirty && !saver.current!.pending) return;
      event.preventDefault();
      if (navigation.current) return;
      navigation.current = true;
      void saver
        .current!.flush()
        .then(() => {
          if (alive.current) router.visit(visit.url, visit);
        })
        .catch(() => {})
        .finally(() => {
          navigation.current = false;
        });
    });
    const unload = (event: BeforeUnloadEvent) => {
      saver.current!.change(latest.current);
      if (saver.current!.dirty || saver.current!.pending) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", unload);
    return () => {
      alive.current = false;
      remove();
      window.removeEventListener("beforeunload", unload);
      // Browser back/forward does not emit Inertia's cancellable before event.
      saver.current!.change(latest.current);
      if (saver.current!.dirty) void saver.current!.flush().catch(() => {});
    };
  }, []);
  useEffect(() => {
    if (state.phase !== "error" || state.conflict) return;
    const timeout = window.setTimeout(() => {
      void flush().catch(() => {});
    }, 5000);
    return () => window.clearTimeout(timeout);
  });
  const saveCopy = async (onCopy: (copy: InvoiceForm) => void) => {
    const copy = {
      ...latest.current,
      line_items_attributes: latest.current.line_items_attributes
        .filter((item) => !item._destroy)
        .map(({ id: _id, ...item }) => item),
    };
    const writer = saver.current!;
    if (writer.pending) await writer.pending.catch(() => {});
    writer.identity = {
      id: null,
      client_key: crypto.randomUUID(),
      lock_version: 0,
      season_id: seasonId,
      invoice_id: null,
    };
    writer.failed = null;
    writer.saved = "";
    latest.current = copy;
    writer.change(copy);
    onCopy(copy);
    await writer.flush(true);
    return copy;
  };
  return { state, flush, saveCopy, identity: saver.current.identity };
}
