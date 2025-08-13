Full‑Text Search Improvement Plan

Overview (current baseline)
- A tsvector column (search_vector) exists (or is being added) with a GIN index and a trigger to keep it updated.
- search_content(query, limit: N)
  - Splits the query into unique alphanumeric terms.
  - Uses an index‑friendly predicate: search_vector @@ (q1 || q2 || ...).
  - Computes per‑word similarity ratio: matched_terms_count / total_terms.
  - Orders by similarity DESC, then updated_at DESC.
  - Filters to status = 'processed'.

Goals
- Reduce write‑time overhead, improve read performance and ranking quality, and simplify maintenance.

1) Replace trigger with a generated (stored) search_vector column (PostgreSQL 12+)
- Why: Avoid trigger overhead and keep the vector consistent automatically. Generated stored columns are computed by the database and persisted on disk.
- Plan (zero/minimal downtime, using concurrent index where possible):
  1. Add a new generated column with weights per field (optional), STORED.
  2. Create a GIN index concurrently on the new column.
  3. Swap consumers to the new column name (or rename columns).
  4. Drop the old trigger, function, and index.

Example migration (Rails, PG >= 12):
  class AddGeneratedSearchVector < ActiveRecord::Migration[7.0]
    disable_ddl_transaction!

    def up
      execute <<~SQL
        ALTER TABLE ragdoll_documents
        ADD COLUMN search_vector_v2 tsvector
        GENERATED ALWAYS AS (
          setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(metadata->>'summary', '')), 'B') ||
          setweight(to_tsvector('english', coalesce(metadata->>'keywords', '')), 'B') ||
          setweight(to_tsvector('english', coalesce(metadata->>'description', '')), 'C')
        ) STORED;
      SQL

      add_index :ragdoll_documents, :search_vector_v2, using: :gin, algorithm: :concurrently, name: 'index_ragdoll_docs_search_vector_v2_gin'

      # Optional: switch application code to use `search_vector_v2`.
      # After verifying reads are working, drop old trigger/index/column and rename:
      # remove_index :ragdoll_documents, name: 'index_ragdoll_documents_on_search_vector'
      # execute "DROP TRIGGER IF EXISTS ragdoll_search_vector_update ON ragdoll_documents;"
      # execute "DROP FUNCTION IF EXISTS ragdoll_documents_vector_update();"
      # remove_column :ragdoll_documents, :search_vector
      # rename_column :ragdoll_documents, :search_vector_v2, :search_vector
      # add_index :ragdoll_documents, :search_vector, using: :gin, algorithm: :concurrently
    end

    def down
      remove_index :ragdoll_documents, name: 'index_ragdoll_docs_search_vector_v2_gin'
      remove_column :ragdoll_documents, :search_vector_v2
    end
  end

2) Partial GIN index on processed documents
- Why: The query filters on status = 'processed'. A partial index reduces index size and speeds up scans.
- Migration:
  add_index :ragdoll_documents, :search_vector, using: :gin, algorithm: :concurrently,
            name: 'index_ragdoll_docs_search_vector_processed_gin',
            where: "status = 'processed'"

3) Optional: adopt websearch_to_tsquery for more natural queries
- Why: Supports quoted phrases, implicit AND/OR, and minus operator (e.g., "foo bar -baz").
- How: Use websearch_to_tsquery('english', :query) for the WHERE predicate.
- Scoring: If keeping the per‑term ratio, you can still split the original query into terms for similarity calculation while using websearch_to_tsquery for filtering. Alternatively, switch to ts_rank_cd and/or weighted tsvectors for ranking.

Example predicate swap:
  where("#{table_name}.search_vector @@ websearch_to_tsquery('english', ?)", query)

4) Improve ranking quality with weights and ts_rank
- Why: Rank title hits higher than description/summary, and leverage PostgreSQL’s ranking.
- How: In the generated column, set weights: title 'A', summary/keywords 'B', description 'C' (as shown above). Then compute and select ts_rank_cd(search_vector, tsquery) as a secondary/primary score.
- Combine with similarity ratio or fully replace it, depending on UX requirements.

5) Unaccent and normalization
- Why: Accented character insensitivity improves recall. Lowercasing is already handled.
- How: Enable unaccent extension and wrap fields: to_tsvector('english', unaccent(...)). For a generated column, apply unaccent in its expression. Note: This requires creating the extension and may slightly increase compute cost.

Migration snippet:
  enable_extension 'unaccent'
  # then use unaccent(...) in the generated column expression and reindex

6) Keyword array search improvements
- Use parameter binding instead of constructing array literals by string concatenation (safer and cleaner):

  # Any overlap
  where('keywords && ?::text[]', normalized_keywords)

  # Contains all
  where('keywords @> ?::text[]', normalized_keywords)

- Index: Add a GIN index on keywords to accelerate these queries:
  add_index :ragdoll_documents, :keywords, using: :gin, algorithm: :concurrently

7) Internationalization / language dictionary selection
- If documents may not be English, consider per‑document dictionaries.
- Options:
  - Store a language code per document and build language‑specific vectors (requires dynamic dictionary in generated column;
    if not feasible, consider a generic/simple dictionary or multiple columns per language).

8) Operational maintenance
- Periodic VACUUM (AUTO is usually fine) and ANALYZE; monitor pg_stat_statements for search queries.
- Keep an eye on dead tuples due to frequent updates if triggers remain.

9) Benchmarking guidance
- Use EXPLAIN (ANALYZE, BUFFERS) before and after each change.
- Test on representative data sizes; measure:
  - Planning and execution time
  - Shared hit vs read ratios
  - Rows examined vs rows returned
  - Index usage (Bitmap Index Scan expected for GIN)

10) Instrumentation
- Log search timings and returned counts per query.
- Sample a subset of queries with EXPLAIN to detect regressions early.

Implementation notes
- Each step above can be deployed independently. Start with the partial index (2), then move to the generated column (1), then consider ranking and query parser refinements (3/4/5) based on product requirements.
