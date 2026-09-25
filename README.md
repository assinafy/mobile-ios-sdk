# SDK iOS da Assinafy

*Português · [Read in English](README.en.md)*

Acesso nativo em Swift e Objective-C à [API Assinafy v1](https://api.assinafy.com.br/v1/docs) —
plataforma brasileira de assinatura eletrônica: documentos, signatários, assignments, campos, tags,
templates, workspaces, webhooks e autenticação.

O SDK cobre todas as operações do documento OpenAPI v1 publicado. As requisições são
`async`/`await` primeiro, com wrappers de completion handler para Objective-C. As respostas
decodificam em modelos tipados, e as falhas aparecem como quatro tipos distintos de erro Swift que
fazem bridge limpo para `NSError`.

Sem dependências de terceiros: apenas Foundation e CryptoKit.

## Sumário

1. [Requisitos](#requisitos)
2. [Instalação](#instalação)
3. [Início rápido](#início-rápido)
4. [Configurando o cliente](#configurando-o-cliente)
5. [As quatro formas de autenticar](#as-quatro-formas-de-autenticar)
6. [OAuth 2.1 com PKCE](#oauth-21-com-pkce)
7. [Como as credenciais são enviadas](#como-as-credenciais-são-enviadas)
8. [O ciclo de vida da assinatura](#o-ciclo-de-vida-da-assinatura)
9. [Métodos de verificação do signatário](#métodos-de-verificação-do-signatário)
10. [O lado do signatário](#o-lado-do-signatário)
11. [Templates](#templates)
12. [Tags, campos e JSON não tipado](#tags-campos-e-json-não-tipado)
13. [Workspaces e webhooks](#workspaces-e-webhooks)
14. [Paginação](#paginação)
15. [Tratamento de erros](#tratamento-de-erros)
16. [Transporte e segurança de rede](#transporte-e-segurança-de-rede)
17. [Objective-C](#objective-c)
18. [Mapa de recursos](#mapa-de-recursos)
19. [Ambientes](#ambientes)
20. [Testes](#testes)
21. [Versionamento](#versionamento)

## Requisitos

| | |
| --- | --- |
| iOS | 16.0+ |
| macOS | 12.0+ |
| Swift | 6.3+ (modo de linguagem 6) |
| Xcode | 26.6+ |
| TLS | 1.2+ (o SDK recusa TLS 1.0 e 1.1) |

Swift e Xcode não têm canal de release LTS. Estas são as versões estáveis atuais da toolchain
contra as quais este pacote é compilado e testado.

## Instalação

Adicione o pacote e o produto ao `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/assinafy/mobile-ios-sdk.git",
        from: "1.8.0"
    ),
],
targets: [
    .target(
        name: "SeuApp",
        dependencies: [
            .product(name: "Assinafy", package: "mobile-ios-sdk"),
        ]
    ),
]
```

No Xcode, escolha **File → Add Package Dependencies…** e informe a URL do repositório.

## Início rápido

Enviar um PDF para um signatário:

```swift
import Assinafy

let client = AssinafyClient(token: bearerToken, defaultAccountId: accountId)

let enviado = try await client.documents.upload(pdfData)
let documento = try await client.documents.waitUntilReady(documentId: enviado.id)

let signatario = try await client.signers.create(
    CreateSignerPayload(fullName: "Ana Souza", email: "ana@exemplo.invalid")
)

let assignment = try await client.assignments.create(
    documentId: documento.id,
    payload: .withSignerIds([signatario.id], method: .virtual, message: "Por favor, revise e assine.")
)
```

## Configurando o cliente

Crie **um** cliente e mantenha uma referência forte a ele. `AssinafyClient` é thread-safe e seus
objetos de recurso são visões sem estado sobre um transporte compartilhado.

```swift
import Assinafy

let configuration = AssinafyClientConfiguration(
    token: bearerToken,        // ou apiKey:, nunca os dois
    baseURL: AssinafyClientConfiguration.productionBaseURL,
    defaultAccountId: accountId,
    timeout: 30,
    logger: NoopLogger()
)
try configuration.validate()
let client = AssinafyClient(configuration: configuration)
```

`defaultAccountId` é aplicado a toda chamada com escopo de conta. Qualquer método que receba um
argumento `accountId` o sobrescreve naquela chamada.

A configuração **falha fechada**. `validate()` rejeita credenciais conflitantes ou malformadas,
timeout não positivo ou não finito, identificador inseguro, e qualquer URL base que não seja uma
URL HTTPS absoluta livre de informação de usuário, query e fragmento. As mesmas checagens rodam em
toda requisição, então um cliente construído sem chamar `validate()` lança `ValidationError` antes
de fazer I/O de rede, em vez de enviar uma requisição malformada.

Algumas operações não precisam de credencial alguma. Deixe as duas de fora para login, redefinição
de senha, as rotas públicas de documento e a troca de tokens OAuth:

```swift
let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration())

let session = try await publicClient.auth.login(
    LoginPayload(email: email, password: password)
)
```

## As quatro formas de autenticar

| Forma | Quem é autenticado | Onde usar |
| --- | --- | --- |
| **Chave de API** (`X-Api-Key`) | O workspace, permanentemente | Back-end confiável |
| **Token bearer** (`Authorization`) | O usuário que fez login | App móvel distribuído |
| **OAuth 2.1** (`Authorization`) | Um app agindo **em nome de** um usuário, com escopos que ele aprovou | Integrações de terceiros, assistentes de IA |
| **Código de acesso do signatário** | Um signatário, para um documento | O lado de quem assina |

> **Escolha a credencial que combina com onde o código roda.** Uma chave de API permanente concede
> acesso permanente a todo o workspace e pertence a um back-end confiável — **nunca** a um bundle
> de app, de onde pode ser extraída. Tokens bearer e tokens OAuth pertencem a apps móveis.

OAuth é a escolha certa quando o código **não é** o dono do workspace: o usuário aprova um conjunto
nomeado de permissões numa tela de consentimento da Assinafy, e o token resultante fica limitado a
elas e a um único workspace. Independentemente dos escopos, um token OAuth nunca alcança cobrança,
ciclo de vida da conta, gestão de credenciais ou superfícies administrativas.

## OAuth 2.1 com PKCE

Fluxo de authorization code com **PKCE S256 obrigatório**. Um app móvel é um *cliente público*:
autentica-se por PKCE e nunca recebe um client secret — um segredo embarcado no bundle pode ser
extraído dele.

> **Disponível apenas em produção.** O host de sandbox ainda não expõe os endpoints OAuth.

### Escopos

| Escopo | Concede |
| --- | --- |
| `documents:read` | Ler documentos, páginas, tags, signatários, assignments e atividades |
| `documents:write` | Criar, atualizar e excluir documentos e gerenciar seus signatários e assignments |
| `templates:read` | Ler templates, suas páginas, papéis, campos e tags |
| `templates:write` | Criar, atualizar e excluir templates e seu conteúdo |
| `account:read` | Ler o perfil, o tema e o logo do workspace |
| `webhooks:write` | Configurar e desativar a assinatura de webhooks do workspace |
| `openid` | Identificar o usuário autenticado e habilitar `/oauth/userinfo` |
| `profile` | Incluir o nome do usuário nas claims |
| `email` | Incluir o e-mail e seu status de verificação nas claims |
| `offline_access` | Receber um refresh token, para continuar funcionando sem novo consentimento |

Passe `OAuthScope.webhooksWrite` pelo inicializador `scopeStrings` de `OAuthAuthorizationRequest` ao solicitar acesso a webhooks.

O usuário aprova tudo o que foi pedido ou nada: peça o mínimo e leia `scope` na resposta do token
para saber o que foi concedido. Uma chamada sem o escopo que exige responde `403` com
`WWW-Authenticate: Bearer error="insufficient_scope", scope="…"`, e `APIError.insufficientScope`
devolve esse escopo: peça ao usuário para conectar de novo incluindo-o, porque repetir a chamada não
resolve. Um `403` sem esse desafio indica outro workspace, o papel do próprio usuário ou uma área que
tokens OAuth nunca alcançam.

### 1. Descubra o servidor de autorização

```swift
let recurso = try await client.oauth.protectedResourceMetadata()
let servidor = try await client.oauth.authorizationServerMetadata(
    issuer: recurso.authorizationServers[0]
)
```

A descoberta é opcional — `OAuthResource.defaultAuthorizationEndpoint` e `defaultIssuer` trazem os
valores de produção — mas os metadados publicados são a fonte autoritativa, e ambas as rotas são
públicas e não carregam credencial alguma.

### 2. Monte a URL de autorização

```swift
let pedido = OAuthAuthorizationRequest(
    clientId: clientId,
    redirectURI: "https://meuapp.exemplo.invalid/oauth/callback",
    scopes: [.documentsRead, .documentsWrite, .offlineAccess],
    resource: recurso.resource
)

let url = pedido.authorizationURL(endpoint: servidor.authorizationEndpoint)!
```

`OAuthAuthorizationRequest` já gera o par PKCE e um `state` imprevisível. **Guarde `pedido` em
memória** até a troca do código: ele carrega o `codeVerifier`, que nunca vai para a URL, para o
disco ou para um log.

O `redirectURI` precisa ser um endereço `https://` cadastrado na aplicação, idêntico caractere a
caractere: a Assinafy não aceita esquema próprio (`meuapp://`) nem `http://localhost`. Abra `url`
numa `ASWebAuthenticationSession`; no iOS 17.4+ e no macOS 14.4+, `callback: .https(host:path:)`
recebe o retorno num host dos domínios associados do app. Em versões anteriores, a página `https://`
cadastrada pode repassar o retorno inteiro para o esquema próprio do app.

### 3. Verifique o retorno

```swift
let codigo = try OAuthCallback(callbackURL: callbackURL)!
    .validate(against: pedido, issuer: servidor.issuer)
```

`validate(against:issuer:)` confere antes de tudo o `state`, em tempo constante, e o parâmetro `iss`
(RFC 9207) — tanto na aprovação quanto num retorno de erro. Um `state` ou `iss` divergente significa
que o redirect não veio do fluxo que este app iniciou, e nada nele é usado. Só então o método lança o
erro relatado pelo servidor (`access_denied`, `invalid_scope`, …) ou devolve o código. Sem `issuer:`,
o `iss` é comparado com `OAuthResource.defaultIssuer`.

### 4. Troque o código por um token

```swift
let token = try await client.oauth.exchangeAuthorizationCode(
    .authorizationCode(
        code: codigo,
        redirectURI: pedido.redirectURI,
        codeVerifier: pedido.pkce.codeVerifier,
        clientId: clientId,
        resource: recurso.resource
    )
)

var clienteDoUsuario = AssinafyClient(token: token.accessToken)
let workspaceId = try await clienteDoUsuario.workspaces.list().data[0].id
```

O código vale uma única vez e expira 60 segundos depois da aprovação: troque-o na hora e, se a troca
falhar, comece uma nova autorização — o SDK nunca repete a requisição. Com um token OAuth,
`workspaces.list()` devolve exatamente o workspace que o usuário escolheu. Guarde `workspaceId` junto
dos tokens e use-o como `defaultAccountId` ou `accountId:`: uma conexão vale para um único
workspace, e qualquer outro responde `403`, mesmo que o usuário pertença a ele.

### 5. Renove e revogue

```swift
// Grave os tokens assim que chegarem, junto de `workspaceId`.
try gravarTokens(token)

// Quando o access token expirar, ou uma chamada responder 401: envie o último refresh token gravado.
let enviado = try refreshTokenGravado()
let novo = try await client.oauth.refreshAccessToken(
    .refreshToken(enviado, clientId: clientId)
)
try gravarTokens(novo)   // antes de tudo: `enviado` já está aposentado
clienteDoUsuario = AssinafyClient(token: novo.accessToken, defaultAccountId: workspaceId)

// Quando o usuário desconectar: revogue o último refresh token gravado e apague os tokens.
let ultimo = try refreshTokenGravado()
try await client.oauth.revoke(OAuthRevokePayload(token: ultimo, clientId: clientId))
try apagarTokens()
```

`gravarTokens`, `refreshTokenGravado` e `apagarTokens` representam o armazenamento do próprio app
no Keychain. Um cliente guarda o token com que foi criado, então crie um novo a cada access token
renovado.

`refreshToken` só existe quando `offline_access` foi pedido **e** consentido; sem ele, conduza o
usuário pelo fluxo de autorização novamente quando o access token expirar, e revogue o access token
quando ele desconectar.

Cada renovação devolve um **novo** `refreshToken` e aposenta o enviado, e reutilizar um refresh
token aposentado encerra a conexão inteira: todos os tokens param de funcionar e o usuário precisa
conectar de novo. Por isso, grave os novos tokens antes de fazer qualquer outra coisa com a
resposta, envie sempre o último refresh token gravado e faça uma renovação por vez em cada conexão.
Uma resposta de sucesso sem um novo refresh token lança `AssinafySDKError`. O SDK envia cada
requisição de token uma única vez e não segue redirects: um `3xx` chega como `APIError`.

**Quando uma renovação falha sem um erro OAuth** — timeout, conexão perdida, cancelamento, `3xx` ou
`5xx`, resposta sem novo refresh token —, o servidor pode já ter aposentado o token enviado, porque
uma resposta perdida é indistinguível de uma requisição que nunca chegou. Releia o refresh token
gravado e só continue se um token *diferente* tiver sido gravado desde então. Se ainda for o token
enviado, nunca o envie de novo: peça ao usuário para conectar de novo. Só podem ser repetidas as
falhas que comprovadamente aconteceram antes de a requisição sair: um `NetworkError` cujo
`underlyingError` é um `URLError` com código `.cannotFindHost`, `.dnsLookupFailed`,
`.cannotConnectToHost`, `.secureConnectionFailed` ou um dos códigos `.serverCertificate…`.

Um refresh token vale **30 dias**, e cada renovação devolve um novo com mais 30 dias: a conexão só
expira se o app passar 30 dias sem renovar. Um `401` da API significa token expirado ou revogado:
renove uma vez e, se falhar, peça ao usuário para conectar de novo. `invalid_grant` na renovação
significa que a conexão acabou (token já usado ou expirado, acesso revogado, ou nova aprovação com
outras permissões) — peça para conectar de novo em vez de repetir.

Ao desconectar, revogue o último refresh token gravado (ou o access token, quando não houver um):
todos os anteriores já estão aposentados. A revogação sempre responde `200` para qualquer desfecho
de token — inclusive um token inexistente, já revogado ou malformado — de modo que o endpoint não
possa ser usado para descobrir se um token existe.

### Quem é o usuário

```swift
let claims = try await clienteDoUsuario.oauth.userInfo()
print(claims.sub, claims.name as Any, claims.email as Any)
```

Exige `openid`; `name` exige `profile` e `email` exige `email`.

### Falhas

Erros OAuth chegam como `APIError` com um `oauthError` tipado:

```swift
do {
    _ = try await client.oauth.exchangeAuthorizationCode(payload)
} catch let error as APIError {
    switch error.oauthError?.code {
    case "invalid_grant":  break // código expirado, reutilizado, ou verifier errado
    case "invalid_client": break // client_id desconhecido ou desabilitado
    case "invalid_target": break // `resource` divergente do autorizado
    default: break
    }
}
```

## Como as credenciais são enviadas

A API v1 coloca cada operação em uma de três classes de autenticação, e o SDK **impõe** essa
separação em vez de anexar credenciais indiscriminadamente.

| Classe | Como a API autentica | O que o SDK envia |
| --- | --- | --- |
| **Conta** | `Authorization: Bearer {token}` ou `X-Api-Key: {chave}` | O header da credencial configurada |
| **Signatário** | O parâmetro de query exato `signer-access-code={código}` | Apenas o parâmetro de query |
| **Público** | Nada | Nada |

Um cliente configurado com token bearer ou chave de API **não** o transmite a uma operação de
Signatário ou Pública. Isso significa que um mesmo cliente pode servir os dois lados de um fluxo: a
mesma instância pode gerenciar documentos com uma credencial de conta e conduzir um signatário por
`assignments.sign(…)` sem que aquela credencial saia das rotas que a aceitam.

A regra vale também por origem: uma requisição cuja URL não compartilha a origem da URL base — como
a descoberta OAuth no servidor de autorização — perde os headers de credencial no transporte,
qualquer que seja a configuração do cliente.

Códigos de acesso são segredos. Trate um `signerAccessCode` exatamente como trataria uma senha:
nunca registre em log, nunca persista além da sessão de assinatura, e nunca o coloque em uma URL
que você compartilhe.

## O ciclo de vida da assinatura

Um pedido de assinatura passa por cinco etapas. Cada uma tem uma chamada dedicada.

```
enviar ──▶ aguardar processamento ──▶ criar signatários ──▶ estimar ──▶ criar assignment
```

### 1. Envie o documento

```swift
let enviado = try await client.documents.upload(
    pdfData,
    options: DocumentUploadOptions(accountId: accountId)
)
```

O SDK confere os magic bytes do PDF e o limite de 25 MB da plataforma localmente, então um arquivo
inválido falha imediatamente com `ValidationError` em vez de gastar uma ida ao servidor.

### 2. Aguarde o processamento

Um documento recém-enviado está em `metadata_processing` e ainda não pode receber assignment nem
ser excluído:

```swift
let documento = try await client.documents.waitUntilReady(
    documentId: enviado.id,
    options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
)
```

`waitUntilReady` retorna assim que o documento alcança `metadataReady`, `pendingSignature`,
`certificating` ou `certificated`. Lança `AssinafySDKError` num status terminal (`failed`,
`expired`, `rejectedBySigner`, `rejectedByUser`) ou quando o prazo expira, e honra cancelamento de
tarefa do início ao fim.

### 3. Crie os signatários

```swift
let signatario = try await client.signers.create(
    CreateSignerPayload(fullName: "Ana Souza", email: "ana@exemplo.invalid")
)
```

A criação é idempotente por e-mail: o SDK procura um signatário existente com o mesmo endereço e o
devolve em vez de criar um duplicado, e se recupera da mesma forma de um `409`. Signatários também
podem ser criados apenas com o nome completo.

### 4. Estime o custo

Pedidos de assinatura consomem documentos e créditos. Confira antes de se comprometer:

```swift
let pedido = CreateAssignmentPayload.withSignerIds(
    [signatario.id],
    method: .virtual,
    message: "Por favor, revise e assine."
)

let estimativa = try await client.assignments.estimateCost(
    documentId: documento.id,
    payload: pedido
)
guard estimativa.hasSufficientResources else {
    throw AssinafySDKError(estimativa.blockingReason ?? "Recursos insuficientes na conta")
}
```

`CostEstimate` traz o `breakdown` tipado, os saldos `documentBalance` e `creditBalance`, e um
`blockingReason` entre `PendingPayment`, `InsufficientDocuments` e `InsufficientCredits`.

### 5. Crie o assignment

```swift
let assignment = try await client.assignments.create(
    documentId: documento.id,
    payload: pedido
)
```

Use `.virtual` para assinatura remota por notificação, e `.collect` para coleta presencial de
campos, que exige também as posições dos campos nas páginas. Para assinatura ordenada, construa os
signatários com `SignerReference.signer(id:verification:notifications:step:)` e dê a cada um o seu
`step`.

### Acompanhe e recupere o resultado

```swift
let progresso = try await client.documents.getSigningProgress(documentId: documento.id)
let concluido = try await client.documents.isFullySigned(documentId: documento.id)
let historico = try await client.documents.activities(documentId: documento.id)

let pdfAssinado = try await client.documents.downloadArtifact(
    documentId: documento.id,
    artifact: .certificated
)
```

As atividades devolvem todos os eventos registrados, cada um com um snapshot do `payload` do evento
e a `origin` da requisição (`ip`, `user-agent`).

| Artefato | Conteúdo |
| --- | --- |
| `original` | O PDF enviado, como recebido |
| `certificated` | O documento assinado, com a certificação da plataforma |
| `certificate-page` | Apenas a página de certificação |
| `pades` | Assinaturas ICP-Brasil dos signatários + caixa de certificação — só existe em documentos que tiveram signatários por certificado digital |
| `bundle` | Zip com `original`, `certificated` e `certificate-page`, mais o `pades` quando houver |

Miniaturas e páginas isoladas têm métodos próprios. Quem tiver o hash da assinatura confere um
documento finalizado sem autenticação alguma:

```swift
let verificacao = try await client.documents.verifyDetails(signatureHash: hash)
```

### Tudo numa chamada só

`uploadAndRequestSignatures` executa a mesma orquestração do lado do dono:

```swift
let opcoes = AssinafyClient.UploadOptions(signers: [
    AssinafyClient.SignerInput(name: "Ana Souza", email: "ana@exemplo.invalid"),
])
opcoes.message = "Por favor, revise e assine."

let (documento, assignment) = try await client.uploadAndRequestSignatures(
    documentData: pdfData,
    options: opcoes
)
```

Valida cada signatário — nomes não vazios, endereços bem formados, nenhum e-mail duplicado
ignorando maiúsculas — antes de enviar o arquivo, de modo que entrada inválida não deixe um
documento órfão para trás. As etapas remotas não são transacionais: se uma etapa posterior falhar,
o documento e os signatários já criados continuam disponíveis para nova tentativa ou limpeza
explícita.

## Métodos de verificação do signatário

Definidos por signatário ao criar o assignment. O método de verificação e o de notificação são
**acoplados**: envie um, os dois ou nenhum — o lado que faltar é inferido. Sem nenhum dos dois,
ambos assumem `Email`.

| Método | Como funciona | Custo por signatário |
| --- | --- | --- |
| `.email` *(padrão)* | Código de uso único (OTP) por e-mail, exigido antes de assinar | Gratuito |
| `.whatsapp` | Código de uso único (OTP) por WhatsApp | Verificação gratuita; notificação 0,45 crédito, só em planos pagos |
| `.digitalCertificate` | O signatário assina com o **próprio certificado ICP-Brasil (A1/A3)**, pela extensão de navegador Web PKI, gerando uma assinatura **PAdES qualificada** | 2 créditos |

```swift
let pedido = CreateAssignmentPayload(
    method: .virtual,
    signers: [
        .signer(id: primeiro.id, verification: .email, step: 1),
        .signer(id: segundo.id, verification: .digitalCertificate, step: 2),
    ]
)
```

Combinações permitidas: `.email` → notifica por `.email`; `.whatsapp` → notifica por `.whatsapp`;
`.digitalCertificate` → notifica por `.email` **ou** `.whatsapp`. Apenas um método de notificação
por signatário.

**A1 e A3** são os dois formatos de certificado ICP-Brasil: A1 é um arquivo de software guardado na
máquina do signatário, A3 vive num cartão inteligente ou token USB. Ambos são apresentados pela
mesma extensão Web PKI, então a escolha entre eles é do signatário e não exige nada da integração.

O certificado digital exige o recurso habilitado na conta (planos Standard e Pro), CPF ou CNPJ em
`government_id`, e que o signatário esteja **sozinho no seu passo**. Um CPF exige o certificado
daquela pessoa — um e-CPF, ou um e-CNPJ que a nomeie como representante legal; um CNPJ exige um
e-CNPJ daquela empresa, de qualquer um de seus representantes.

> Como a assinatura por certificado acontece por um handshake com a extensão de navegador Web PKI,
> ela não é concluída pelo fluxo de assinatura nativo deste SDK — encaminhe o signatário à página
> web de assinatura.

Ao ler um signatário de volta, `signatario.verification` e `signatario.notifications` devolvem os
valores tipados, e `nil` ou uma lista reduzida quando o servidor manda algo que esta versão do SDK
não conhece.

## O lado do signatário

Um signatário chega com um código de acesso vindo do convite. A sequência completa é: ler o
documento, aceitar os termos, confirmar os dados de identidade e então assinar.

```swift
func assinarAssignmentVirtual(
    client: AssinafyClient,
    documentId: String,
    assignmentId: String,
    accessCode: String,
    nomeCompleto: String,
    email: String
) async throws {
    _ = try await client.signers.getSelf(signerAccessCode: accessCode)
    try await client.signers.acceptTermsWithoutResponse(signerAccessCode: accessCode)
    _ = try await client.documents.confirmSignerDataAndReturnSigner(
        documentId: documentId,
        signerAccessCode: accessCode,
        payload: ConfirmSignerDataPayload(
            fullName: nomeCompleto,
            email: email,
            hasAcceptedTerms: true
        )
    )
    try await client.assignments.sign(
        documentId: documentId,
        assignmentId: assignmentId,
        signerAccessCode: accessCode
    )
}
```

Confirmar os dados do signatário é obrigatório em assignments virtuais; assinar sem isso devolve
`400`. O signatário pode, em vez disso, recusar:

```swift
try await client.assignments.decline(
    documentId: documentId,
    assignmentId: assignmentId,
    signerAccessCode: accessCode,
    reason: "Destinatário incorreto"
)
```

Signatários com vários documentos podem agir sobre todos de uma vez com
`signers.signMultipleDocuments(…)` e `signers.declineMultipleDocuments(…)`, e listar os próprios
documentos com `signers.listSignerDocuments(…)` e `signers.searchSignerDocuments(…)`.

Imagens de assinatura e rubrica são PNG:

```swift
try await client.signers.uploadSignature(
    signerAccessCode: accessCode,
    type: .signature,
    imageData: pngData,
    reuse: true
)
```

Quando o link de assinatura carrega apenas um código de acesso e nenhum ID de signatário, use
`signers.getSigningDocument(signerAccessCode:)`.

Antes de o signatário verificar seu código, um app pode mostrar um resumo público e enviar o token
de seis dígitos:

```swift
let info = try await client.documents.getPublicInfo(documentId: documentId)

try await client.documents.sendPublicSignToken(
    documentId: documentId,
    email: "ana@exemplo.invalid"
)
```

## Templates

Crie documentos a partir de um template reutilizável mapeando papéis para signatários:

```swift
let templates = try await client.templates.list(
    params: TemplateListParams(search: "Contratação")
)

let documento = try await client.documents.createFromTemplate(
    templateId: templateId,
    signers: [TemplateSigner(roleId: roleId, id: signatario.id)],
    options: CreateDocumentFromTemplateOptions(name: "Carta proposta")
)
```

`documents.estimateCostFromTemplate(…)` precifica o mesmo pedido antes.

`TemplateSigner` também aceita métodos tipados:

```swift
TemplateSigner(roleId: roleId, id: signatario.id, verification: .whatsapp)
```

A listagem de templates e a criação de documentos a partir deles são operações v1. A gestão da
definição de templates — `templates.create(name:pdfData:)`, `get`, `update` e `delete` — existe na
API ao vivo mas não consta do documento OpenAPI publicado; confirme a disponibilidade no seu
ambiente antes de depender dela.

## Tags, campos e JSON não tipado

```swift
let tag = try await client.tags.create(
    CreateTagPayload(name: "Contratos", color: "ff8800")
)
_ = try await client.tags.appendDocumentTags(documentId: documentId, tagIds: [tag.id])
```

`tags.appendDocumentTags` acrescenta às tags de um documento; `tags.replaceDocumentTags` define
exatamente o conjunto, e passar um array vazio limpa todas.

Definições de campo descrevem valores coletados dos signatários. A validação aceita uma `String`
simples, ou um `JSONValue` quando o campo recebe outro tipo JSON:

```swift
let resultado = try await client.fields.validate(
    fieldId: fieldId,
    value: JSONValue(.integer(42))
)

let lote = try await client.fields.validateMultiple(items: [
    FieldValidateMultipleItem(fieldId: fieldId, value: "2026-08-27"),
])
```

Campos de resposta cujo schema aceita qualquer tipo JSON expõem um `JSONValue` sem perdas ao lado
da visão legada em string:

- `DocumentActivity.originJSON` e `payloadJSON`
- `AssignmentItem.valueJSON`
- `TemplateFieldPlacement.displaySettingsJSON`
- `WebhookDispatch.payloadJSON`

## Workspaces e webhooks

`client.workspaces` mapeia os endpoints de conta: criar, ler, atualizar, excluir, tema de marca,
estatísticas do funil de documentos e o logo da conta.

```swift
let tema = try await client.workspaces.theme()
try await client.workspaces.uploadLogo(pngData)
```

`theme()` é a fonte canônica das cores de marca de uma conta.

Webhooks entregam eventos do ciclo de vida do documento:

```swift
let assinatura = try await client.webhooks.register(
    WebhookRegisterPayload(
        url: "https://exemplo.invalid/hooks/assinafy",
        email: "ops@exemplo.invalid",
        events: ["document.completed"]
    )
)

let tipos      = try await client.webhooks.listEventTypes()
let tentativas = try await client.webhooks.listDispatches()
try await client.webhooks.retryDispatch(dispatchId: tentativas.data[0].id)
```

A API não tem exclusão destrutiva de assinaturas. Interrompa a entrega com `webhooks.inactivate()`;
`webhooks.delete()` está descontinuado e encaminha para ele.

## Paginação

Operações de listagem devolvem `PaginatedResult<T>`. `data` traz a página; `meta` é montado a
partir dos headers `X-Pagination-*` e é `nil` quando o servidor os omite.

```swift
var pagina = 1
var todos: [DocumentListItem] = []
repeat {
    let resultado = try await client.documents.list(params: ListParams(page: pagina, perPage: 100))
    todos += resultado.data
    guard let meta = resultado.meta, pagina < meta.lastPage else { break }
    pagina += 1
} while true
```

## Tratamento de erros

O SDK lança exatamente quatro tipos, mais `CancellationError`:

| Tipo | Significado | Detalhe principal |
| --- | --- | --- |
| `APIError` | A API devolveu um status fora do 2xx | `statusCode`, `message`, `responseData`, `oauthError` |
| `ValidationError` | Validação local falhou antes de qualquer requisição | mapa `errors` por campo |
| `NetworkError` | Falha de transporte — DNS, TLS, timeout | `underlyingError` como `URLError` |
| `AssinafySDKError` | Violação de contrato do SDK | `context`, `underlyingError` |

```swift
do {
    _ = try await client.documents.get(documentId: documentId)
} catch let error as APIError {
    print(error.statusCode, error.message, error.responseData as Any)
    for restricao in error.workspaceDeletionRestrictions {
        print(restricao.code, restricao.accountIds)
    }
} catch let error as ValidationError {
    print(error.message, error.errors)
} catch let error as NetworkError {
    print(error.message, error.underlyingError as Any)
} catch is CancellationError {
    // O cancelamento de tarefa é preservado, não convertido.
}
```

## Transporte e segurança de rede

As requisições passam por uma `URLSession` efêmera com cookies e cache de URL desligados, de modo
que o SDK não grava credencial nem resposta em disco.

Redirects são restritos. `POST /oauth/token` e `POST /oauth/revoke` não seguem nenhum: o corpo
carrega um código ou token, então um `3xx` chega como `APIError` em vez de enviá-lo de novo. Os
demais redirects de mesma origem são seguidos sem alteração. Um redirect para outra origem só é
aceito quando é HTTPS, o método é `GET` ou `HEAD` e não há corpo — o que cobre downloads de
artefatos servidos por outro host. Nesse redirect sobrevivem apenas `Accept`,
`Accept-Encoding`, `Accept-Language`, `Range`, `If-Range` e `User-Agent`; `Authorization`,
`X-Api-Key`, `Cookie` e todo header desconhecido são removidos. Downgrades para HTTP, URLs de
destino com informação de usuário e redirects para outra origem carregando corpo são recusados de
saída.

## Objective-C

Os métodos compatíveis com Objective-C recebem completion handlers, sempre entregues na **main
queue**. O header gerado é a fonte da verdade dos seletores; nem todo auxiliar de concorrência
Swift tem um wrapper de completion.

```objc
ASFAssinafyClient *client = [[ASFAssinafyClient alloc]
    initWithToken:bearerToken
    defaultAccountId:accountId];

[client.signers getSignerWithId:@"signer-id"
                       accountId:nil
                      completion:^(Signer *signer, NSError *error) {
    if (error != nil) {
        NSLog(@"A requisição falhou: %@", error.localizedDescription);
        return;
    }
    NSLog(@"ID do signatário: %@", signer.id);
}];
```

Erros Swift fazem bridge para `NSError` sob os domínios de `ASFErrorDomain`. `code` carrega o
status HTTP em `APIError`, `422` em `ValidationError`, o código de `URLError` em `NetworkError` e
`-1` em `AssinafySDKError`; os detalhes chegam em `userInfo` sob `responseData`, `errors` e
`NSUnderlyingErrorKey`. Um `APIError` também traz o desafio `WWW-Authenticate` bruto sob
`wwwAuthenticate` e, num `403` `insufficient_scope`, o escopo que falta sob `insufficientScope`:

```objc
NSString *escopo = error.userInfo[@"insufficientScope"];
if (escopo != nil) {
    // Peça ao usuário para conectar de novo, solicitando também `escopo`.
}
```

## Mapa de recursos

| Recurso | Cobertura |
| --- | --- |
| `client.auth` | Login, login social e vínculo, operações de senha, gestão de chave de API, usuário atual, preferências de notificação, estatísticas |
| `client.oauth` | Descoberta, URL de autorização com PKCE, troca de código, renovação, revogação, userinfo |
| `client.workspaces` | CRUD de conta, tema, estatísticas, upload/download/exclusão de logo |
| `client.documents` | Envio, listar/buscar/obter/renomear/excluir, status de processamento, páginas, miniaturas, atividades, artefatos, verificação, criação a partir de template, fluxo público de token |
| `client.signers` | CRUD de signatários do workspace, autoatendimento, termos, verificação, imagens de assinatura, documentos do signatário, assinatura e recusa em lote |
| `client.assignments` | Listar, criar, estimar, assinar, recusar, reenviar, expiração, notificações WhatsApp |
| `client.fields` | Definições, tipos de campo, validação simples e em lote |
| `client.tags` | Tags do workspace e vínculos com documentos |
| `client.templates` | Listagem de templates e gestão de definições |
| `client.webhooks` | Assinaturas, tipos de evento, histórico de entrega, reenvio |

[`docs/API_REFERENCE.md`](docs/API_REFERENCE.md) documenta, para cada método, a classe de
autenticação, o caminho HTTP exato, o payload de requisição, o payload de resposta, o
comportamento de compatibilidade e o modelo de erro.

## Ambientes

| | |
| --- | --- |
| Produção | `AssinafyClientConfiguration.productionBaseURL` |
| Sandbox | `https://sandbox.assinafy.com.br/v1` |

Os endpoints OAuth existem apenas em produção.

## Testes

Rode a suíte com concorrência Swift 6 e warnings como erro, depois um build de release:

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

A CI roda ainda o XCTest num simulador iOS 26.5 / iPhone 17 Pro sob Xcode 26.6, compila a DocC com
warnings como erro, verifica compatibilidade da API pública contra a tag anterior mais próxima, e
confere que a tag de release, `sdkVersion`, o changelog e este arquivo concordam.

Os testes ao vivo leem credenciais apenas do ambiente e recusam qualquer host que não seja o
sandbox:

```bash
ASSINAFY_API_KEY="..." \
ASSINAFY_ACCOUNT_ID="..." \
ASSINAFY_BASE_URL="https://sandbox.assinafy.com.br/v1" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Testes que criam recursos no sandbox ou enviam notificações exigem opt-in explícito e dois
destinatários distintos informados em tempo de execução:

```bash
ASSINAFY_RUN_LIVE_MUTATIONS=1 \
ASSINAFY_TEST_EMAIL_A="destinatario-a@exemplo.invalid" \
ASSINAFY_TEST_EMAIL_B="destinatario-b@exemplo.invalid" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Nunca versione credenciais, códigos de acesso, senhas ou endereços de destinatários.

## Versionamento

O pacote segue versionamento semântico. Versões liberadas são marcadas como `vMAJOR.MINOR.PATCH`, e
cada uma é registrada em [CHANGELOG.md](CHANGELOG.md).

## Licença

Distribuído sob a licença [MIT](LICENSE).
