import type { DraftMetadata, InvoiceForm } from "../types";

export type DraftIdentity = Pick<
  DraftMetadata,
  "client_key" | "lock_version" | "invoice_id" | "season_id"
> & { id: number | null };
export type DraftSaveState = {
  phase: "saved" | "waiting" | "saving" | "error";
  error?: string;
  conflict?: boolean;
  metadata?: DraftMetadata;
};
export class DraftSaveError extends Error {
  status: number;
  constructor(message: string, status = 0) {
    super(message);
    this.status = status;
  }
}
type Transport = (
  identity: DraftIdentity,
  data: InvoiceForm,
) => Promise<DraftMetadata>;

// A single serialized writer: edits during a request are sent afterward. Failed
// snapshots are retried verbatim before newer edits, including lost responses.
export class DraftSaver {
  identity: DraftIdentity;
  latest: string;
  saved: string;
  failed: string | null = null;
  pending: Promise<DraftMetadata> | null = null;
  transport: Transport;
  notify: (state: DraftSaveState) => void;
  constructor(
    identity: DraftIdentity,
    data: InvoiceForm,
    transport: Transport,
    notify: (state: DraftSaveState) => void,
  ) {
    this.identity = identity;
    this.latest = this.saved = JSON.stringify(data);
    this.transport = transport;
    this.notify = notify;
  }
  change(data: InvoiceForm) {
    this.latest = JSON.stringify(data);
  }
  get dirty() {
    return this.latest !== this.saved || this.failed !== null;
  }
  async flush(force = false): Promise<DraftMetadata> {
    if (this.pending) {
      await this.pending;
      return this.flush(force);
    }
    if (!this.dirty && !(force && !this.identity.id))
      return this.identity as DraftMetadata;
    const snapshot = this.failed ?? this.latest;
    this.notify({ phase: "saving" });
    const operation = this.transport(
      { ...this.identity },
      JSON.parse(snapshot) as InvoiceForm,
    );
    this.pending = operation;
    try {
      const metadata = await operation;
      this.identity = metadata;
      this.saved = snapshot;
      this.failed = null;
      this.notify({ phase: "saved", metadata });
    } catch (error) {
      this.failed =
        error instanceof DraftSaveError &&
        error.status >= 400 &&
        error.status < 500
          ? null
          : snapshot;
      this.notify({
        phase: "error",
        error:
          error instanceof Error
            ? error.message
            : "Couldn't save this draft. Please retry.",
        conflict: error instanceof DraftSaveError && error.status === 409,
      });
      throw error;
    } finally {
      this.pending = null;
    }
    return this.dirty ? this.flush() : (this.identity as DraftMetadata);
  }
}
