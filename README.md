# Taskify – Conceptual Guide

This guide accompanies a lab session where we followed a scripted exercise to build a working Flutter prototype. The practical goals were to configure a Flutter project, model the task entity, wire a SQLite data service, and expose a basic CRUD interface.

## Objectives

- Configure a Flutter project
- Implement the data model
- Create a SQLite database service
- Develop a basic CRUD flow

Below we recap the key concepts that underpin those steps, so you can revisit the theory after completing the hands-on work.

This document summarises the core theory behind the Taskify prototype, focusing on two pillars of Flutter development:

1. Local persistence with SQLite
2. Reactive widgets and state management

## 1. Local Persistence with SQLite

- **Why it matters:** SQLite ships inside the app bundle, giving you a structured offline store without servers or extra services.
- **Schema at a glance:** Tasks live in a single `tasks` table with an `id`, title, description, `completed` flag, priority, and timestamps—mapping cleanly to Dart objects.
- **CRUD flow:** `CREATE TABLE` runs on first launch; helpers wrap `INSERT`, `SELECT`, `UPDATE`, and `DELETE` so widgets can call methods instead of raw SQL. Always use async/await to keep the UI responsive and parameterised queries to stay safe.
- **Lifecycle hints:** The database file sits in the documents directory resolved by `path_provider`. When you bump the `version`, add an `onUpgrade` callback to migrate schema without data loss.

## 2. Reactive Widgets and State Management

- **Declarative approach:** Flutter rebuilds widgets whenever state changes, so the UI is always a reflection of the current data.
- **State containers:** `StatefulWidget` + `setState` often suffice for small views; the `State` object caches mutable data like lists, filters, or counters.
- **Async awareness:** Database calls return futures—once they complete, update state and let Flutter re-render the list, counters, and filters automatically. Guard with `mounted` to avoid updating disposed widgets.
- **Scaling up:** As screens multiply, consider structured state managers (Provider, Riverpod, BLoC, etc.) that separate UI from persistence logic. Even in small apps, keep SQLite calls inside dedicated services so widgets stay lean and testable.
