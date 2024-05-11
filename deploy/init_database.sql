CREATE TABLE "public"."storage" (
    "id" integer NOT NULL,
    "data" text NOT NULL
) WITH (oids = false);

CREATE UNIQUE INDEX storage_idx on storage (id) WHERE (id):