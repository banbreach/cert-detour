# cert-detour — A Disposable Browser Lab for TLS Revocation Compatibility Testing

> **Security warning — intentionally old browser**
>
> This Codespace deliberately uses the older Kasm Chrome image release
> `kasmweb/chrome:x86_64-1.18.0`. Its sole purpose is temporary compatibility
> access to websites that remain inaccessible in a current browser because
> the website is still presenting an affected TLS server certificate revoked
> following the eMudhra incident documented in
> [Mozilla Bug 2082408](https://bugzilla.mozilla.org/show_bug.cgi?id=2082408).
>
> This is a deliberate reduction in browser security and certificate-revocation
> protection. It is **not a security fix**, not a general-purpose browser, and
> not suitable for sensitive transactions. Use it only for a specific,
> understood compatibility need and only after accepting the risks described
> below.

## 1. Correct incident attribution and purpose

The compatibility scenario documented here is associated with **Mozilla
Bug 2082408**, not Bug 2083449.

### Bug 2082408: TLS certificate validity exceeded the eMudhra CP/CPS limit

Bug 2082408 concerns eMudhra issuing TLS server certificates whose validity
period was **90 days and one second**, exceeding the 90-day maximum specified
in Section 6.3.2 of the emSign SSL/TLS CP/CPS for certificates issued on or
after 19 November 2025.

The full incident report in Bug 2082408 states:

- 15,032 affected TLS server certificates were issued between 19 November
  2025 and 15 October 2026.
- 8,116 were time-valid when the issue was identified or were issued after
  identification.
- Of those 8,116, 7,761 were revoked between 15 and 19 October 2026; the
  remaining 355 expired before revocation.
- The report records zero affected certificates remaining valid.
- The excess validity resulted from an inclusive-period calculation: setting
  `notAfter` to exactly `notBefore + 90 days` produces a validity interval of
  90 days plus one second when both endpoints are counted.
- The report says the issue did not affect key generation, domain or
  organization validation, or other certificate content. The certificates
  were revoked for compliance reasons, using the `superseded` reason code.

This setup is intended only for the downstream compatibility problem where
a website continues to present one of those affected, revoked TLS server
certificates and a current browser blocks the connection because of its
revocation handling. An older browser may have different or stale revocation
information and may therefore behave differently. **That outcome is not
guaranteed**: Chrome's actual version, its revocation mechanisms, the site's
current certificate chain, and any locally enforced policy all matter.

This is not a root-certificate revocation scenario. Bug 2082408 is about
affected **end-entity TLS server certificates** being revoked after a
certificate-validity policy violation. Do not describe it as removal or
revocation of an eMudhra root certificate.

### Bug 2083449 is a separate incident

[Mozilla Bug 2083449](https://bugzilla.mozilla.org/show_bug.cgi?id=2083449)
tracks a different and substantially more serious issue: compromise of the
private keys of eight eMudhra intermediate CA certificates, associated with
a cryptographic weakness in their key generation.

That intermediate-CA key-compromise incident is **not the cause addressed
by this compatibility setup**. In particular, this README does not attribute
the Bug 2082408 website-access problem to weak P-384 root keys or to the
intermediate-key compromise described in Bug 2083449. The affected
certificates, failure mechanism, and security implications are different.

### Intended long-term remedy

The website operator should stop serving an affected revoked certificate
and deploy a replacement TLS certificate that complies with applicable
requirements and chains to a currently trusted CA hierarchy. Users should
then return to a supported, up-to-date browser.

A website loading in this old browser does not prove that its certificate is
currently valid, trusted, or safe to use.

## 2. Components

- Image: `kasmweb/chrome:x86_64-1.18.0`
- Desktop access: KasmVNC web interface on container port `6901`
- Forwarded protocol: HTTPS
- Container startup: the image's own entrypoint and command are preserved
  using `overrideCommand: false`
- Shared memory: `512 MiB`
- Authentication: KasmVNC Basic Authentication, username `kasm_user`
- Password source: GitHub Codespaces secret `KASM_VNC_PASSWORD`

The image is designed to be accessed through a browser at
`https://<host>:6901` in standalone deployments. Kasm documents `kasm_user`
as the default username. KasmVNC uses the `~/.kasmpasswd` file for its web
Basic-Auth credentials.

The image tag `1.18.0` identifies the Kasm image/Workspaces release line; it
does **not** identify the bundled Chrome version. After launch, record the
actual browser version at `chrome://version`. Do not assume the image tag
alone tells you which Chrome security fixes or revocation data are present.

## 3. Configure the Codespaces secret

Create a Codespaces secret named exactly:

```text
KASM_VNC_PASSWORD
```

Suggested steps:

1. In GitHub, open **Settings → Codespaces**.
2. Under **Codespaces secrets**, choose **New secret**.
3. Set the name to `KASM_VNC_PASSWORD`.
4. Set a unique, high-entropy password of 12–128 characters. Avoid newline
   characters.
5. Grant access only to the repository that needs this browser.
6. Save the secret.

For an organization-managed repository, an organization or repository
Codespaces secret can be used if permitted by the organization's policy.
Do not put the password in `devcontainer.json`, a Dockerfile, a checked-in
`.env` file, a README, a shell command, or a GitHub Actions secret.

If adding the secret to an already-running Codespace, stop and restart that
Codespace so the secret becomes available. A rebuild alone is not a
substitute for restarting after adding a secret.

### Why the password is applied after startup

Codespaces secrets are made available to the running Codespace environment;
they are not available during image build or inside the container's initial
entrypoint. The `postStartCommand` therefore runs
`.devcontainer/set-kasm-password.sh` after Kasm has started.

The script reads `KASM_VNC_PASSWORD` from the Codespaces lifecycle
environment and updates the KasmVNC password file using `kasmvncpasswd`.
It does not print the secret or save it in the repository.

**Do not forward port 6901 until the post-start hook has completed
successfully.** Automatic forwarding is deliberately disabled so that the
desktop is not exposed before its password has been replaced.

## 4. Start and access the desktop

1. Ensure the Codespaces secret exists and is scoped to this repository.
2. Create a new Codespace, or stop and restart an existing one.
3. Wait for the `postStartCommand` to finish. It should print:

   ```text
   KasmVNC password configured from the Codespaces secret.
   ```

   If it reports a missing secret or an error, do not forward the port.
4. Open the Codespaces **Ports** panel.
5. Forward port `6901` manually.
6. Set its visibility to **Private**. Do not set it to Public.
7. Open the forwarded HTTPS URL.
8. Sign in with username `kasm_user` and the value stored in
   `KASM_VNC_PASSWORD`.

Only port `6901` is intended to be forwarded. Do not forward the raw VNC
port `5901` or audio port `4901`.

### Basic health checks

From the Codespaces terminal:

```bash
# Confirm Kasm startup processes exist.
ps -ef | grep -E 'kasm|Xvnc|chrome' | grep -v grep

# Confirm the web port is listening.
ss -lntp | grep ':6901'

# Check the local HTTPS endpoint.
curl -k -I https://127.0.0.1:6901/
```

A `200` or `302` response is a useful indication that the web endpoint is
responding. It does not prove that a particular website's certificate will
be accepted or that the resulting connection is secure.

To inspect the actual browser build, open:

```text
chrome://version
```

## 5. Usage rules

This environment is for short-lived, narrowly scoped compatibility access.

- Use it only for a specific website whose current-browser failure has been
  confirmed to be related to a TLS certificate affected by Bug 2082408.
- Check the site's currently served certificate and chain first. Do not
  assume that every eMudhra-issued certificate is affected.
- Prefer read-only access.
- Do not use it for banking, payments, tax filing, government services,
  healthcare, email, password managers, corporate SSO, cryptocurrency,
  privileged administration, or any workflow involving sensitive data.
- Do not enter passwords, authentication codes, payment information,
  private keys, API tokens, or personal/confidential information.
- Do not download or execute files. Do not install extensions or software.
- Do not use the browser for general web surfing.
- Do not click through certificate warnings for unrelated certificate
  errors.
- Close the browser session and stop the Codespace when the compatibility
  task is complete.
- Prefer the website operator's replacement certificate as soon as it is
  available, then return to a supported browser.

A legacy browser may not receive current revocation information or security
updates. If it accepts a revoked certificate, that is a reduction in
server-authentication assurance—not evidence that the certificate has become
valid again. The setup cannot repair the certificate, reverse its revocation,
or establish that the site is safe.

## 6. Threat model

### Assets to protect

- GitHub repository contents and any files mounted into the Codespace
- Codespaces environment variables, credentials, and other accessible
  development-environment data
- Browser cookies, session tokens, browsing history, and downloaded content
- Information entered into websites
- Integrity and confidentiality of traffic to the destination website
- The KasmVNC desktop session and its authentication credentials

### Trust boundaries

1. **User → GitHub Codespaces:** GitHub account authentication and Codespaces
   access controls govern access to the development environment.
2. **Browser → KasmVNC:** HTTPS and KasmVNC Basic Authentication protect the
   remote desktop endpoint. The forwarded port must remain Private.
3. **Kasm Chrome → target website:** TLS certificate and revocation checks
   are performed by an intentionally old browser and its bundled trust and
   revocation data. This is the principal weakened boundary.
4. **Browser process → Codespace:** A browser exploit may compromise the
   browser process and potentially access files or processes available to
   the container user, including the mounted workspace.
5. **Codespace → GitHub platform:** The container is isolated by the
   Codespaces platform, but this setup does not make browser compromise
   harmless or eliminate access to data available inside the Codespace.

### Adversaries and failure scenarios

| Threat | Why it matters here | Mitigation / residual risk |
|---|---|---|
| Network attacker able to intercept traffic | If the old browser does not know about the revocation of an affected server certificate, it may accept a certificate that a current browser rejects. | Use only for low-sensitivity, scoped access. A revoked certificate must be treated as untrusted even if this browser accepts it. Interception or impersonation remains possible. |
| Malicious or compromised target website | Old Chrome may lack security fixes and may be vulnerable to web-originated attacks. | Restrict use to the intended site; avoid downloads, extensions, and sensitive sessions. Browser exploitation remains a material risk. |
| Malicious website content or drive-by exploit | A browser compromise may expose the Codespace user's files and processes. | Use a disposable Codespace with no sensitive repository data. Treat workspace contents as potentially exposed after a browser compromise. |
| Unauthorized access to KasmVNC | Anyone able to reach the forwarded desktop could control or observe the session if authentication is weak or exposed. | Use a unique high-entropy Codespaces secret; forward only port 6901; keep it Private; never publish the port. |
| Secret leakage | A committed password or logged command could expose desktop access. | Store only in Codespaces secrets; do not echo it, commit it, or pass it as a command-line argument. Restrict repository access to the secret. |
| Persistent browser data | Cookies, cache, and downloads may remain in the Codespace profile or workspace. | Avoid signing in; do not download files; stop and delete the Codespace after use when practical. |
| Misdiagnosed certificate failure | A site may fail for reasons unrelated to Bug 2082408. | Inspect the served certificate chain and browser error. Do not treat this image as a universal TLS bypass. |
| Confusion with the separate Bug 2083449 incident | The intermediate-CA private-key compromise has a different cause and security impact. | Attribute this compatibility use case to Bug 2082408 only. Do not use this image to justify trusting certificates affected by the separate key-compromise incident. |

### Security properties intentionally weakened

This project intentionally uses an old browser whose certificate-revocation
state and enforcement may differ from those of a current browser. In the
specific compatibility scenario, that difference may allow the browser to
connect to a website still presenting a TLS server certificate revoked in
connection with Bug 2082408.

That behavior weakens **server-authentication assurance**. It does not undo
the revocation, make the certificate compliant, repair the website's TLS
configuration, or prove that the endpoint is controlled by the legitimate
website operator. It may also expose the user to browser vulnerabilities
fixed in later releases.

The Bug 2082408 report describes a one-second CP/CPS validity-limit
non-compliance; it does not report that the affected certificates' keys or
domain-validation results were compromised. This distinction does not make
accepting a revoked certificate safe: revocation is the control that relying
parties are expected to honor.

### Out of scope

- Protecting sensitive credentials or transactions
- Providing a trusted browsing environment for general use
- Reversing the revocation of certificates affected by Bug 2082408
- Restoring trust to certificates affected by the separate Bug 2083449
  intermediate-key compromise
- Replacing the site's TLS certificate or repairing its PKI configuration
- Guaranteeing compatibility with every affected website

## 7. Operational checklist

Before each use:

- [ ] Confirm that the website's currently served TLS certificate is among
      those affected by Bug 2082408, or otherwise establish the precise
      revocation-related failure.
- [ ] Do not confuse Bug 2082408 with the separate intermediate-key
      compromise tracked in Bug 2083449.
- [ ] Use a disposable Codespace with no sensitive repository data.
- [ ] Confirm the post-start password hook succeeded.
- [ ] Forward only port `6901`.
- [ ] Confirm port visibility is **Private**.
- [ ] Confirm the actual browser version at `chrome://version`.
- [ ] Do not enter sensitive information or download/execute files.

After use:

- [ ] Close the browser session.
- [ ] Stop the Codespace.
- [ ] Delete the Codespace if it is no longer needed.
- [ ] Return to a supported, updated browser when the site deploys a
      replacement certificate.

## 8. References

- [Mozilla Bug 2082408: eMudhra emSign PKI Services — TLS certificates exceed
  CP/CPS maximum validity period by one second](https://bugzilla.mozilla.org/show_bug.cgi?id=2082408)
- [Mozilla Bug 2083449: eMudhra — Private key compromise of Intermediate
  Certificates](https://bugzilla.mozilla.org/show_bug.cgi?id=2083449)
- [Kasm Chrome image documentation](https://hub.docker.com/r/kasmweb/chrome)
- [KasmVNC configuration and password-file documentation](https://docs.kasmvnc.com/docs/configuration/)
- [KasmVNC server-side documentation](https://docs.kasmvnc.com/docs/serverside/)
- [GitHub Docs: Managing Codespaces secrets](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces)
- [GitHub Docs: Persisting environment variables and temporary files](https://docs.github.com/en/codespaces/developing-in-a-codespace/persisting-environment-variables-and-temporary-files)

---

**Status:** Temporary compatibility aid with a deliberately reduced
security posture. The preferred remediation is for the affected website
operator to deploy a replacement, compliant TLS certificate and for users
to return to a current, supported browser.
