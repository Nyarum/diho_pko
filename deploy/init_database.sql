CREATE SEQUENCE accounts_id_seq INCREMENT 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE TABLE "public"."accounts" (
    "id" integer DEFAULT nextval('accounts_id_seq') NOT NULL,
    "login" text,
    "password" text,
    "mac" text,
    "is_cheat" integer NOT NULL,
    "client_version" integer NOT NULL,
    "pincode" text,
    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
) WITH (oids = false);

CREATE SEQUENCE characters_id_seq INCREMENT 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE TABLE "public"."characters" (
    "id" integer DEFAULT nextval('characters_id_seq') NOT NULL,
    "account_id" integer NOT NULL,
    "name" text NOT NULL,
    "map" text NOT NULL,
    "look" text NOT NULL,
    "hair" integer NOT NULL,
    CONSTRAINT "characters_pkey" PRIMARY KEY ("id")
) WITH (oids = false);