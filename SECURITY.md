# Security operations

See [data protection and quota verification](docs/DATA_PROTECTION_QUOTAS_VERIFICATION.md) before deploying this working tree. Deployment requires an externally provisioned Cookie encryption key, an offline explicit account migration, reviewed backups, and independent acceptance. No production migration or cleanup was performed by this change.

- Keep one runtime/replica. Local JSON storage/scheduler and quota accounting are not multi-worker safe.
- Store the encryption key outside the checkout/data archive, owner-readable only. Back up key and encrypted data separately; losing the matching key loses access. Never rotate or regenerate a production key implicitly.
- Use TLS. Exclude Authorization, Cookie headers and all query strings from reverse-proxy/access/error logs. Media capability URLs are bearer secrets.
- `accounts.json` is authenticated encrypted as a whole, including proxy credentials. Browser profiles/downloads, task prompts and media are NOT encrypted by this mechanism. Protect the entire runtime filesystem with OS encryption, restrictive access and bounded backup retention.
- App operational messages intentionally omit all details rather than attempting unsafe exception redaction. Uvicorn access messages are suppressed before formatting. DOM debug dumps are disabled. Third-party process/proxy logs require separate operator configuration.
- Storage quota measures persisted generated media, not Muse credits, request count, temp browser downloads, profile/cache bytes or total filesystem consumption. OS/container filesystem quotas remain required to bound those other paths.
- Unknown or symlinked media are logically quarantined: inaccessible, never auto-adopted after the one-time legacy ownership migration, never retention-deleted; new writes refuse until explicit operator reconciliation.
- Deletion unlinks active files; it is not secure erase, upstream Muse deletion or backup erasure. Stop workers and reconcile backups separately when erasing a tenant.
