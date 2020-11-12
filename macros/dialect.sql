
{# Macros that translate from SQL Server to SQLite dialect #}

{% macro substring_fn() %}
	{%- if adapter.config.credentials.type == 'sqlite' -%}
	SUBSTR
	{%- else -%}
	SUBSTRING
	{%- endif -%}
{% endmacro %}

{% macro len_fn() %}
	{%- if adapter.config.credentials.type == 'sqlite' -%}
	LENGTH
	{%- else -%}
	LEN
	{%- endif -%}
{% endmacro %}

{% macro concat_fn() %}
	{%- if adapter.config.credentials.type == 'sqlite' -%}
	LENGTH
	{%- else -%}
	LEN
	{%- endif -%}
{% endmacro %}

{# this one does string replacment on caller 'body' #}
{% macro concat() %}
	{%- if adapter.config.credentials.type == 'sqlite' -%}
		{{ caller()|replace('+','||') }}
	{%- else -%}
		{{ caller() }}
	{%- endif -%}
{% endmacro %}

{% macro getdate_fn() %}
	{%- if adapter.config.credentials.type == 'sqlite' -%}
		DATETIME('NOW')
	{%- else -%}
		GETDATE()
	{%- endif -%}
{% endmacro %}
