---
name: surrealdb-schema-design
description: Design SurrealDB schemas correctly. Use when deciding between indexed fields vs graph relations, structuring DEFINE TABLE/FIELD/INDEX statements, choosing SCHEMAFULL vs SCHEMALESS, or modeling ownership, relationships, and access permissions in SurrealDB.
---

Apply the following schema design guidelines when working with SurrealDB.

Task:
$ARGUMENTS

---

## Core principle: choose the right relationship model

### Indexed field (for ownership / simple filtering)

Use an indexed `userId` field when the query is a one-hop filter — "give me all records belonging to this user."

```sql
DEFINE FIELD userId ON item TYPE record<user>;
DEFINE INDEX idx_item_user ON item FIELDS userId;

SELECT * FROM item WHERE userId = user:123;
```

**Why:** Fewer records to write and maintain. SurrealDB indexes trade a small write cost for significantly faster reads. No edge record is created — just a typed field on the owned record.

### Graph relation (for traversal and relationship-rich data)

Use `RELATE` when the relationship itself carries meaning, needs metadata, or requires multi-hop traversal.

```sql
RELATE user:123->owns->item:abc SET created_at = time::now();
SELECT ->owns->item FROM user:123;
SELECT <-owns<-user FROM item:abc; -- reverse traversal
```

**Why:** Graph edges are real records with `in`, `out`, and arbitrary fields. They support bidirectional and multi-hop traversal natively. SurrealDB's arrow syntax is designed for this.

---

## Decision table

| Query pattern | Preferred model | Reason |
|---|---|---|
| `SELECT * FROM post WHERE userId = user:123` | Indexed field | Simple one-hop filter. Fewer writes. |
| "Get user's posts / orders / documents" | Indexed field | Ownership is not a graph problem. |
| "Get friends of friends" | Graph relation | Traversal is the point. |
| "User liked post with score / timestamp / source" | Graph relation | Relationship has metadata. |
| "Find paths / recommendations / social graph" | Graph relation | Multi-hop graph traversal. |
| "Reverse lookup needed occasionally" | Either | Indexed field works; graph is cleaner if bidirectional traversal is frequent. |

**Rule of thumb:**

- `user -> documents / messages / tasks / products / embeddings` → indexed `userId` field
- `user follows user / user likes post / document cites document / agent used tool` → graph relation

---

## Table definition

### Prefer SCHEMAFULL for application tables

```sql
DEFINE TABLE user SCHEMAFULL;
DEFINE TABLE post SCHEMAFULL;
```

SCHEMAFULL rejects unknown fields at write time, preventing silent schema drift. Use SCHEMALESS only for exploratory or log/event tables where shape is unknown at design time.

### Always type record-link fields

```sql
DEFINE FIELD userId ON post TYPE record<user>;
DEFINE FIELD authorId ON comment TYPE record<user>;
```

This enforces referential type safety. SurrealDB will reject writes where the value is not a record ID of the correct table.

### Define all fields explicitly on SCHEMAFULL tables

```sql
DEFINE FIELD title   ON post TYPE string;
DEFINE FIELD body    ON post TYPE string;
DEFINE FIELD userId  ON post TYPE record<user>;
DEFINE FIELD createdAt ON post TYPE datetime VALUE time::now() READONLY;
DEFINE FIELD updatedAt ON post TYPE datetime VALUE time::now();
```

Use `VALUE` for computed defaults and `READONLY` to prevent mutation after creation.

---

## Index design

### Index every field used in WHERE, ORDER BY, or JOIN-equivalent traversal

```sql
DEFINE INDEX idx_post_user     ON post     FIELDS userId;
DEFINE INDEX idx_post_created  ON post     FIELDS createdAt;
DEFINE INDEX idx_comment_post  ON comment  FIELDS postId;
```

### Composite indexes for multi-field filters

```sql
DEFINE INDEX idx_post_user_created ON post FIELDS userId, createdAt;
```

Use composite indexes when queries consistently filter on two fields together. Column order matters: put the equality-filtered column first, the range/sort column second.

### Unique indexes for natural keys

```sql
DEFINE INDEX idx_user_email ON user FIELDS email UNIQUE;
DEFINE INDEX idx_user_handle ON user FIELDS handle UNIQUE;
```

### Full-text search indexes

```sql
DEFINE ANALYZER standard TOKENIZERS class FILTERS lowercase, snowball(english);
DEFINE INDEX idx_post_search ON post FIELDS title, body SEARCH ANALYZER standard BM25;

SELECT * FROM post WHERE title @@ 'surrealdb schema' OR body @@ 'surrealdb schema';
```

Use `SEARCH ANALYZER` + `BM25` for full-text search rather than `string::contains` or regex, which do full scans.

---

## Permissions

### Define row-level access on SCHEMAFULL tables

```sql
DEFINE TABLE post SCHEMAFULL
  PERMISSIONS
    FOR select WHERE userId = $auth.id OR $auth.role = 'admin'
    FOR create, update WHERE userId = $auth.id
    FOR delete WHERE userId = $auth.id OR $auth.role = 'admin';
```

Permissions are evaluated per-row at query time. `$auth` is the authenticated record (e.g. `user:123`). Prefer DEFINE TABLE permissions over application-layer filtering to enforce security at the database level.

---

## Graph relation patterns

### Edge with metadata

```sql
DEFINE TABLE likes SCHEMAFULL TYPE RELATION IN user OUT post;
DEFINE FIELD score     ON likes TYPE number;
DEFINE FIELD createdAt ON likes TYPE datetime VALUE time::now() READONLY;

RELATE user:123->likes->post:abc SET score = 5;
```

### Multi-hop traversal

```sql
-- Friends of friends
SELECT ->follows->user->follows->user FROM user:123;

-- Documents cited by documents this user authored
SELECT ->authored->document->cites->document FROM user:123;
```

### Prevent duplicate edges with a unique index

```sql
DEFINE INDEX idx_likes_unique ON likes FIELDS in, out UNIQUE;
```

---

## Common mistakes to avoid

| Mistake | Fix |
|---|---|
| Using graph `RELATE` for every ownership relationship | Use indexed `userId` field for simple one-to-many ownership |
| SCHEMALESS on all tables | Use SCHEMAFULL for application entities; reserve SCHEMALESS for logs/events |
| Missing index on foreign-key-like fields | Always index fields used in WHERE filters and record-link traversal |
| Relying on `string::contains` for search | Use SEARCH ANALYZER + BM25 full-text index |
| Untyped record link fields | Use `TYPE record<tableName>` to enforce referential type safety |
| No permissions defined | Define row-level permissions on SCHEMAFULL tables; do not rely solely on application logic |
| Composite index with wrong column order | Equality columns first, range/sort columns last |

---

## Write cost reminder

A graph edge is a full record:

```sql
likes:xyz { in: user:123, out: post:abc, score: 5, createdAt: ... }
```

An indexed ownership field is just a field on an existing record:

```sql
post:abc { userId: user:123, ... }
```

Graph edges add write amplification. This is acceptable — and the right choice — when the relationship is semantically meaningful. It is wasteful when ownership is the only query pattern.

SurrealDB 3.0 significantly improved graph query performance, but that benchmark compares SurrealDB versions, not graph edges vs indexed fields for the same workload. Do not assume graph is faster simply because it is "native."
