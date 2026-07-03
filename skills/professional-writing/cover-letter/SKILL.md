---
name: cover-letter
description: Use when the user wants to write, draft, or tailor a professional cover letter or job application letter for a specific role — given a job description and a candidate profile (résumé, portfolio, or bio) in any format (URL, text, or PDF).
---

# Writing a Cover Letter

## Overview

Produce a tailored, evidence-backed cover letter that maps a candidate's concrete
work to what a company is *actually* optimizing for — not the bullet points, the
need behind them.

**Core principle:** Every sentence earns its place by proving fit with specific
evidence. If a claim can't be traced to a real item in the candidate profile,
it doesn't go in the letter.

## When to Use

- User wants a cover letter, application letter, or "letter of interest" for a job
- User provides a job posting + a résumé/profile and asks you to connect them
- User has a generic letter and wants it tailored to a specific role

**When NOT to use:**
- Résumé/CV writing (different structure and conventions)
- LinkedIn bios or generic "about me" blurbs with no target role

## Inputs

Two required inputs. Each may arrive as a **URL, raw text, or PDF** — detect the
format and extract clean text before analyzing.

| Input | What it is | Ingestion |
|-------|-----------|-----------|
| `job_description` | Target role, team, company | URL → fetch, strip to posting body. PDF → extract full text. Text → use verbatim. |
| `candidate_profile` | Résumé, portfolio, or bio | URL → fetch content. PDF → extract, preserve sections (experience, skills, projects). Text → use verbatim. |

**If either input is missing, ambiguous, or unreadable: STOP and ask the human
partner.** Never invent employers, dates, metrics, projects, or skills to fill a
gap — fabrication is the fastest way to produce a letter that gets the candidate
caught in an interview.

## Execution Workflow

Three phases, in order. Do not advance until the current phase's output exists.

### Phase 1 — Strategic Alignment Analysis
**Use `superpowers:writing-plans` to structure this analysis.**

- Read past the bullet points. Identify what the company is *really* optimizing
  for — the unspoken need (e.g., technical judgment over marketing polish, ability
  to triage a high-volume GitHub firehose, genuine AI-literacy).
- Map the candidate's specific technical profile (e.g., Python, SQL, data
  engineering automation, daily AI-agent usage, infrastructure tinkering) directly
  onto each underlying need.
- **Output:** a needs → evidence alignment matrix. Every company need should have
  at least one concrete profile item pointing at it. Flag needs with no evidence —
  those become gaps to bridge in Phase 2.

### Phase 2 — Ideation & Calibration
**Use `superpowers:brainstorming` to generate and pressure-test angles.**

- Brainstorm specific narrative hooks drawn from the candidate's *actual* projects
  (automation workflows, open-source interactions, hardware tinkering like a
  Raspberry Pi rig). A hook is a story, not an adjective.
- For each gap flagged in Phase 1, formulate an honest bridging strategy — frame
  transferable skills for what they are (e.g., data engineering + system automation
  → community triage and infrastructure scaling, standing in for traditional DevRel
  experience). Bridge the gap; never pretend it isn't there.
- **Output:** 2–3 candidate narrative angles, each anchored to real evidence, with
  the transferable-skill bridges made explicit. Pick the strongest with the user
  if it's a close call.

### Phase 3 — Execution & Refinement
**Consult `superpowers:requesting-code-review` conventions for the final deliverable.**

- Draft the letter in a **technical, conversational, yet authoritative** tone.
- Replace every soft claim with an evidence-backed assertion tied to Phase 1's
  matrix and Phase 2's chosen hook.
- Self-check against the Negative Constraints below before presenting.
- **Output:** the finished cover letter, plus a one-line note on which hook you led
  with and why.

## Negative Constraints

Strip these out on every pass:

- ❌ **Corporate fluff** — "passionate", "dynamic", "self-starter", "results-driven",
  "team player", "think outside the box", "hit the ground running".
- ❌ **Unbacked claims** — every assertion traces to a concrete profile item.
- ❌ **Fabrication** — no invented employers, dates, metrics, or skills.
- ❌ **Boilerplate openings** — no "Dear Hiring Manager, I am writing to apply for
  the position of…".
- ❌ **Keyword mirroring** — don't echo the job description's phrasing mechanically;
  prove fit through evidence.
- ❌ **Hidden gaps** — bridge missing experience honestly; don't paper over it.

## Quick Reference

| Do | Instead of |
|----|-----------|
| "I cut our nightly ETL from 40 min to 6 by rewriting the SQL join strategy." | "I am a results-driven data professional." |
| "I run Claude agents daily to triage my own repo's issues." | "I am highly AI-literate." |
| Open with the strongest project hook | "I am writing to express my interest in…" |
| Name the company's real need, then the evidence | List generic strengths |

## Common Mistakes

- **Skipping Phase 1** and jumping to prose → generic letter that fits any job.
- **Leading with the candidate instead of the company's need** → reads self-centered.
- **Listing skills instead of proving them** → assertions without evidence.
- **Over-claiming to hide a gap** → collapses under interview scrutiny.
- **Matching the JD's wording too closely** → reads as keyword-stuffed, not tailored.
