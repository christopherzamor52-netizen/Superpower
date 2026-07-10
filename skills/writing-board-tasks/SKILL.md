---
name: writing-board-tasks
description: "Use when turning an approved design or spec into task cards for a project board — Jira/Confluence {panel} markup, backlog items, refinement, or handoff to a team. Keywords: board, card, ticket, backlog, panel, história, requisitos. NOT for TDD implementation plans (use writing-plans)."
---

# Writing Board Tasks

## Visão geral

Converte um design aprovado (saída de brainstorming) em **cards de tarefa para um board** (Jira/Confluence), num layout fixo de 4 painéis. Um card de board é uma unidade de trabalho **voltada ao negócio e ao acompanhamento** — não é um plano de implementação técnico.

**Princípio central:** cada card diz *o que* precisa ser entregue e *como saber que deu certo*, em linguagem que PO, dev e QA entendem — sem ditar a implementação.

**Diferença de writing-plans:** `writing-plans` gera passos técnicos de TDD (arquivos, interfaces, testes) para o executor. Esta skill gera cards de acompanhamento no board. São complementares e independentes — uma feature pode ter um card de board E um plano de implementação.

## Quando usar

- Você tem um design/spec aprovado e precisa abrir tarefas num board (backlog, refinement, handoff para um time).
- Precisa do formato `{panel}` do Jira/Confluence.

**Quando NÃO usar:**
- Para o plano de implementação técnico (tasks TDD, arquivos, interfaces) → use **superpowers:writing-plans**.
- Antes de existir um design → use **superpowers:brainstorming** primeiro.

## Decomposição: quantos cards?

- Um card por **unidade entregável e rastreável de valor** — uma capacidade que o board acompanha de forma independente (o que uma pessoa/PR pega e conclui de ponta a ponta).
- **Não** quebre em micro-passos (isso é do `writing-plans`). **Não** junte features independentes num card só.
- **Preocupações transversais** (threading, tratamento de erros, logging, performance) **não viram cards próprios** — entram como requisitos/guardrails nos cards entregáveis que as usam. Um card "Threading" ou "Tratamento de erros global" não é acompanhável como valor de negócio.
- Se o brainstorming decompôs o projeto em sub-projetos, cada sub-projeto é um epic e seus fluxos/telas viram cards.
- Regra prática: se o "Contexto" precisa de dois *porquês* distintos, provavelmente são dois cards.

## O formato

Cada card começa com um **título curto de negócio** (verbo + resultado, ex.: "Traduzir texto selecionado via atalho global"), seguido dos 4 painéis nesta ordem exata:

```
{panel:title= 1. Contexto da Tarefa}

...

{panel}

{panel:title= 2. Requisitos da tarefa}

...

{panel}

{panel:title= 3. Saída esperada da tarefa}

...

{panel}

{panel:title= 4. Informações complementares}

...

{panel}
```

## O que vai em cada painel

Preencha cada painel pelo que ele **é**. Não misture os papéis — o mesmo fato aparece em um único painel.

**1. Contexto da Tarefa** — a "história" resumida, administrativa/de negócio. O *porquê*: qual problema ou necessidade, para quem, e que valor entrega. 2 a 5 frases. Sem detalhe técnico de implementação.

**2. Requisitos da tarefa** — o que a tarefa **precisa atender**, em lista **numerada**, com subitens quando fizer sentido. Requisitos funcionais e regras de negócio, cada um uma afirmação **verificável** ("O sistema deve..."). Não descreve *como* implementar.
```
1. Requisito principal
   1.1. Subitem / detalhe
   1.2. ...
2. Próximo requisito
```

**3. Saída esperada da tarefa** — como deve se comportar **depois de pronto**: critérios de aceite, guardrails, o que precisa dar certo, o que validar, e o comportamento em erros/casos de borda. É o *definition of done observável*, não a lista de requisitos de novo. Prefira Dado/Quando/Então ou checklist de validação.

**4. Informações complementares** — o que ajuda a executar mas não é requisito: URLs de endpoints, como autenticar, links para doc/design, variáveis de ambiente, dependências, contatos. Se não houver nada relevante, escreva `—` (não invente).

## Exemplo (um card, a partir de um design)

**Título:** Traduzir texto selecionado via atalho global

```
{panel:title= 1. Contexto da Tarefa}

Quem lê conteúdo em outros idiomas precisa traduzir trechos sem sair do fluxo — hoje é preciso copiar o texto, abrir um tradutor e colar. Esta tarefa permite traduzir o texto selecionado em qualquer aplicativo com um único atalho global, mostrando o resultado num popup discreto perto do cursor. É o fluxo de tradução mais usado do app residente na bandeja.

{panel}

{panel:title= 2. Requisitos da tarefa}

1. Disparar a tradução da seleção atual por atalho global.
   1.1. No Windows, o atalho gera evento direto no processo.
   1.2. No GNOME/Wayland, o atalho é o comando `ocr-translator --action=translate-selection`, que envia a ação via IPC à instância viva.
2. Obter o texto selecionado sem poluir o clipboard de forma perceptível ao usuário.
3. Auto-detectar o idioma de origem.
4. Traduzir para o idioma de destino configurado, usando o provider padrão das configurações.
5. Exibir o resultado num popup perto do cursor, com texto original, tradução e botão de copiar.

{panel}

{panel:title= 3. Saída esperada da tarefa}

- Dado um texto selecionado, quando o atalho é acionado, o popup mostra origem + tradução sem travar a interface.
- Seleção vazia: exibe aviso discreto ("nenhum texto selecionado") e encerra, sem popup de erro.
- Falha de tradução (sem internet / provider fora do ar): mensagem clara de "falha na tradução" e sugestão de provider offline; o app não quebra.
- O clipboard do usuário permanece inalterado ao final do fluxo.
- O botão copiar coloca a tradução no clipboard.
- Chamadas de rede rodam fora da thread da UI.

{panel}

{panel:title= 4. Informações complementares}

- Providers: Google (HTTP, sem chave, com auto-detecção) e Argos (offline); padrão vem das configurações.
- IPC (GNOME): a instância viva expõe um socket local; `--action=translate-selection` conecta e entrega a ação.
- Seleção primária no GNOME: `wl-paste --primary`.
- Design de referência: docs/superpowers/specs/2026-07-09-ocr-translator-design.md (Fluxo A).

{panel}
```

## Erros comuns

- **Contexto virar especificação técnica** — contexto é o *porquê* de negócio; requisitos e comportamento vão nos painéis 2 e 3.
- **Requisitos vagos** ("tratar erros") — troque por afirmação verificável ("Se a seleção estiver vazia, exibir aviso discreto e não abrir popup de erro").
- **Saída esperada repetindo os requisitos** — o painel 3 é sobre *comportamento observável e validação*, não a lista de features outra vez.
- **Card gigante** cobrindo várias features — quebre por unidade entregável.
- **Card por camada técnica** ("Threading", "Camada de persistência", "Tratamento de erros") — o board acompanha valor entregável, não camadas; transversais entram como requisitos/guardrails dos cards de feature.
- **Inventar informação complementar** — se não sabe o endpoint/auth, registre como pendência, não invente.
- **Painel fora de ordem ou markup errado** — mantenha os 4 painéis, na ordem, com `{panel:title= N. ...}` e `{panel}` de fechamento.

## Onde salvar

`docs/superpowers/board-tasks/YYYY-MM-DD-<topico>.md` — um arquivo com todos os cards, ou um por card. Preferências do usuário sobrescrevem.

## Checklist

- [ ] Um card por unidade entregável (decomposição certa)
- [ ] Título de negócio claro (verbo + resultado)
- [ ] Contexto: *porquê* de negócio, resumido, sem implementação
- [ ] Requisitos numerados e verificáveis, com subitens onde útil
- [ ] Saída esperada: aceite + guardrails + validação + casos de erro (não repete requisitos)
- [ ] Info complementar: endpoints/auth/links, ou `—`
- [ ] Os 4 painéis, na ordem, com markup `{panel}` exato
