# Assinafy SDK para iOS

SDK Swift 6 sem dependências externas para a API Assinafy v1. Compatível com iOS 16+ e macOS 12+, com APIs `async/await` e adaptadores Objective-C que retornam na fila principal.

[English](README.en.md) · [Referência completa](docs/API_REFERENCE.md) · [Payloads JSON](docs/PAYLOADS.md) · [API Assinafy](https://api.assinafy.com.br/v1/docs)

## Instalação

No Xcode, adicione este repositório como Swift Package, ou declare:

```swift
.package(url: "https://github.com/assinafy/mobile-ios-sdk.git", from: "1.13.0")
```

O produto é `Assinafy`. Importe-o com `import Assinafy`.

## Autenticação

Use uma credencial por cliente. Nunca distribua uma API key em um aplicativo de terceiros.

```swift
let workspaceClient = AssinafyClient(
    apiKey: apiKey,
    defaultAccountId: accountId
)

let userClient = AssinafyClient(
    token: accessToken,
    defaultAccountId: selectedAccountId
)
```

O transporte exige HTTPS/TLS 1.2+, não segue redirecionamentos de token ou revogação e nunca repete uma requisição automaticamente.

## OAuth 2.1 com PKCE

Apps de marketplace são clientes públicos: callback HTTPS exato, PKCE S256, sem `client_secret`. OAuth está disponível somente em produção.

```swift
let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration())
let resource = try await publicClient.oauth.protectedResourceMetadata()
let server = try await publicClient.oauth.authorizationServerMetadata(
    issuer: resource.authorizationServers[0]
)
let request = OAuthAuthorizationRequest(
    clientId: clientId,
    redirectURI: "https://app.example.invalid/oauth/callback",
    scopes: [.documentsRead, .documentsWrite, .offlineAccess],
    resource: resource.resource
)
let authorizationURL = request.authorizationURL(endpoint: server.authorizationEndpoint)!
```

Abra `authorizationURL` com `ASWebAuthenticationSession` e mantenha `request` até o retorno. O SDK gera PKCE, `state` e `nonce` novos. Valide `state` e `iss` antes de trocar o código:

```swift
let code = try OAuthCallback(callbackURL: callbackURL)!
    .validate(against: request, issuer: server.issuer)
let token = try await publicClient.oauth.exchangeAuthorizationCode(
    .authorizationCode(
        code: code,
        redirectURI: request.redirectURI,
        codeVerifier: request.pkce.codeVerifier,
        clientId: clientId,
        resource: resource.resource
    )
)
```

Se usar `id_token`, valide assinatura, `iss`, `aud`, `exp` e o `nonce` de `request`. Como alternativa, leia identidade com `oauth.userInfo()`. O endpoint de introspecção publicado exige credencial confidencial e não pertence ao app móvel.

Depois da troca:

1. Salve tokens no Keychain.
2. Liste `userClient.workspaces.list()` e escolha um workspace; configure seu ID como `defaultAccountId`.
3. Renove uma vez por conexão, sem concorrência. Cada renovação gira o refresh token: persista o novo antes de usar o access token.
4. Se o resultado da renovação for incerto, não reutilize o token enviado; reconecte o usuário.
5. Ao desconectar, revogue o refresh token mais recente uma única vez e apague o armazenamento local.

Tokens OAuth respeitam escopos e não acessam cobrança, ciclo de vida da conta, administração ou API keys.

## Fluxo completo de assinatura

O fluxo é: upload → processamento → signatários → estimativa → atribuição → confirmação/verificação → assinatura → certificação e download.

```swift
let options = AssinafyClient.UploadOptions(signers: [
    .init(name: "Pessoa Exemplo", email: "signer@example.invalid")
])
let result = try await workspaceClient.uploadAndRequestSignatures(
    documentData: pdfData,
    options: options
)
```

O helper cria uma atribuição virtual por email. Para controle completo, use `documents.upload`, `documents.waitUntilReady`, `signers.create`, `assignments.estimateCost` e `assignments.create`. Uma falha depois do upload não desfaz recursos já criados. Criação idempotente de signatário pode reutilizar um email sem atualizar seus dados; atualize-o explicitamente.

### Métodos de verificação e notificação

| Verificação | Requisitos | Experiência |
| --- | --- | --- |
| `Email` | Notificação Email ou Whatsapp | OTP validado por `signers.verifyEmail` antes da assinatura nativa |
| `Whatsapp` | Plano pago e telefone | OTP pelo canal Whatsapp |
| `IdDocumentFaceMatchBasic` | Recurso habilitado, CPF e Email ou Whatsapp | Consentimento explícito, documento e selfie; pode exigir revisão do workspace |
| `DigitalCertificate` | Recurso habilitado, CPF/CNPJ, atribuição virtual e signatário sozinho na etapa | Certificado ICP-Brasil A1 ou A3 via página web e Web PKI |

Faça `assignments.estimateCost` antes de criar a atribuição. Whatsapp, biometria e certificado podem consumir créditos. A1/A3 nunca envia chave privada ao SDK: abra a URL de assinatura no navegador.

No fluxo biométrico, o signatário consulta `signers.identityVerification` e só chama `startIdentityVerification` após consentimento e `canStart`. Preserve o fragmento da URL e trate-a como segredo. `pending_identity_review` permite assinar, mas retém a certificação. O workspace consulta `assignments.identityReview`; imagem e decisão exigem credencial direta do workspace.

O signatário confirma dados e termos, verifica o OTP quando aplicável, assina e baixa os artefatos pelas rotas com `signer-access-code`. Essas chamadas nunca recebem a credencial do workspace. As formas exatas estão na [referência](docs/API_REFERENCE.md#signers) e no [catálogo de payloads](docs/PAYLOADS.md).

## Templates, contratos e campos

- `templates` cria documentos por papéis e posiciona campos de coleta por página.
- `fields` cria, atualiza e valida definições; `tags` organiza documentos.
- `contracts` gerencia termos, renovações, encerramentos e instrumentos de alteração. Envie `updated_at` para controle otimista e preserve a requisição após resultado incerto.
- `documents` expõe atividades paginadas e artefatos `original`, `certificated`, `certificate-page`, `pades` e `bundle`.

## Webhooks assinados

Crie endpoints com `webhooks.createEndpoint`. Quando `signing_enabled` estiver ativo, salve o `secret` retornado uma única vez no servidor receptor. Verifique `webhook-id`, `webhook-timestamp` e `webhook-signature` sobre o corpo bruto:

```swift
try WebhookSignature.verify(
    payload: rawBody,
    headers: headers,
    secret: secret
)
```

A verificação usa HMAC-SHA256 e janela de 300 segundos. Deduplicate entregas já verificadas por `webhook-id`. Rotacionar o segredo invalida o anterior imediatamente. Apps OAuth podem rotacionar com `webhooks:write`, mas não ler um segredo existente.

## Objective-C, erros e limites

Todos os métodos públicos assíncronos têm uma forma explícita com completion handler entregue na fila principal. Tipos Swift sem representação Objective-C oferecem overloads por string ou JSON.

Erros são `ValidationError`, `APIError`, `NetworkError`, `MFARequiredError` ou `AssinafySDKError`. `APIError` preserva `X-Rate-Limit-Limit`, `X-Rate-Limit-Remaining`, `X-Rate-Limit-Reset`, `Retry-After`, erros OAuth e o escopo insuficiente. O SDK nunca decide quando repetir: respeite o contexto da operação.

## Ambientes e validação

- Produção: `https://api.assinafy.com.br/v1`
- Sandbox: `https://sandbox.assinafy.com.br/v1`
- OAuth, MFA e biometria podem existir somente em produção; consulte a referência antes de planejar testes.

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
```

Testes locais não acessam a rede. Testes ao vivo exigem variáveis de ambiente e ficam restritos ao sandbox; descoberta OAuth pública tem uma flag separada. Nunca grave credenciais, callbacks privados ou destinatários reais no repositório.

## Documentação

- [API_REFERENCE.md](docs/API_REFERENCE.md): todos os métodos, parâmetros, modelos, seletores Objective-C e regras de credencial.
- [PAYLOADS.md](docs/PAYLOADS.md): corpos completos e exemplos sintéticos de resposta.
- [CHANGELOG.md](CHANGELOG.md): histórico de versões.
- [Documentação oficial](https://api.assinafy.com.br/v1/docs): contrato online da API.
