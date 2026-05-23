-- v1.6.0 — Optional plaintext cover-photo handle column on entries.
--
-- Today, an entry's encrypted cover photo path (e.g. "couple-{id}/{uuid}.bin")
-- already lives inside the E2EE ciphertext_b64 blob as EntryPayload.coverHandle.
-- Reading it requires the per-couple chat key.
--
-- This migration adds an *additive* plaintext column so that future
-- server-side features (e.g. media GC, storage reconciliation jobs, or a
-- minimal admin dashboard) can locate the storage object without the chat
-- key. Clients are free to leave this NULL — the encrypted handle inside
-- ciphertext remains the source of truth for rendering.
--
-- Nothing in v1.6.0 reads this column yet; it's reserved for a follow-up
-- once the GC / admin tooling lands. Keeping the change additive means no
-- breaking wire change for already-shipped iOS / Android clients.

alter table public.entries
    add column if not exists photo_src text;
