#!/usr/bin/env python3
import argparse
import json
import re
import urllib.request
from pathlib import Path

UBLOCK_TXT_URL = "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy-removeparam.txt"
CLEARURLS_JSON_URL = "https://gitlab.com/ClearURLs/rules/-/raw/master/data.min.json"

REMOVE_PARAM_PREFIX = "$removeparam="
REGEX_META_RE = re.compile(r"[\\^$.*+?()\[\]{}|]")


def fetch_ublock_removeparam_txt() -> str:
    with urllib.request.urlopen(UBLOCK_TXT_URL, timeout=30) as response:
        return response.read().decode("utf-8")


def fetch_clearurls_data_json() -> dict:
    with urllib.request.urlopen(CLEARURLS_JSON_URL, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def normalize_token(raw_token: str):
    token = raw_token.strip()
    if not token:
        return None, None

    if token.startswith("/") and token.endswith("/") and len(token) > 2:
        token = token[1:-1]

    if "=" in token or REGEX_META_RE.search(token):
        return None, token
    return token.lower(), None


def parse_general_rules(txt_content: str):
    exact = set()
    regex_patterns = []

    for raw_line in txt_content.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("!") or line.startswith("#"):
            continue
        if not line.startswith(REMOVE_PARAM_PREFIX):
            continue

        token = line[len(REMOVE_PARAM_PREFIX):]
        token = token.split(",", 1)[0]

        exact_token, regex_token = normalize_token(token)
        if exact_token:
            exact.add(exact_token)
        elif regex_token:
            regex_patterns.append(regex_token)

    return sorted(exact), regex_patterns


def parse_provider_rules(clearurls_root: dict):
    providers = []
    provider_map = clearurls_root.get("providers", {})

    for provider_name in sorted(provider_map.keys()):
        provider = provider_map[provider_name]
        url_pattern = provider.get("urlPattern")
        if not url_pattern:
            continue

        exact = set()
        regex_patterns = []

        for key in ("rules", "referralMarketing", "rawRules"):
            for token in provider.get(key, []) or []:
                exact_token, regex_token = normalize_token(str(token))
                if exact_token:
                    exact.add(exact_token)
                elif regex_token:
                    regex_patterns.append(regex_token)

        providers.append(
            {
                "name": provider_name,
                "urlPattern": url_pattern,
                "exactParams": sorted(exact),
                "regexParams": regex_patterns,
            }
        )

    return providers


def build_parsed_rules(txt_content: str, clearurls_root: dict):
    general_exact, general_regex = parse_general_rules(txt_content)
    providers = parse_provider_rules(clearurls_root)

    return {
        "_meta": {
            "license": "GPL-3.0",
            "derived_from": [
                "uBlock Origin uAssets (GPL-3.0)",
                "ClearURLs Rules (LGPL-3.0)",
            ],
        },
        "rules": {
            "generalExact": general_exact,
            "generalRegex": general_regex,
            "providers": providers,
        },
    }


def validate_parsed_rules(parsed_rules: dict) -> None:
    required_top_level = {"_meta", "rules"}
    missing = required_top_level.difference(parsed_rules.keys())
    if missing:
        raise ValueError(f"Missing required top-level keys: {sorted(missing)}")

    meta = parsed_rules["_meta"]
    if not isinstance(meta, dict):
        raise ValueError("_meta must be an object")
    if meta.get("license") != "GPL-3.0":
        raise ValueError("_meta.license must be GPL-3.0")
    derived_from = meta.get("derived_from")
    if not isinstance(derived_from, list) or len(derived_from) < 2:
        raise ValueError("_meta.derived_from must be a list with upstream entries")

    rules = parsed_rules["rules"]
    if not isinstance(rules, dict):
        raise ValueError("rules must be an object")
    for key in ("generalExact", "generalRegex", "providers"):
        if key not in rules:
            raise ValueError(f"rules missing key '{key}'")

    if not isinstance(rules["generalExact"], list):
        raise ValueError("generalExact must be a list")
    if not isinstance(rules["generalRegex"], list):
        raise ValueError("generalRegex must be a list")
    if not isinstance(rules["providers"], list):
        raise ValueError("providers must be a list")

    for index, provider in enumerate(rules["providers"]):
        if not isinstance(provider, dict):
            raise ValueError(f"providers[{index}] must be an object")

        for key in ("name", "urlPattern", "exactParams", "regexParams"):
            if key not in provider:
                raise ValueError(f"providers[{index}] missing key '{key}'")

        if not isinstance(provider["name"], str) or not provider["name"]:
            raise ValueError(f"providers[{index}].name must be a non-empty string")
        if not isinstance(provider["urlPattern"], str) or not provider["urlPattern"]:
            raise ValueError(f"providers[{index}].urlPattern must be a non-empty string")
        if not isinstance(provider["exactParams"], list):
            raise ValueError(f"providers[{index}].exactParams must be a list")
        if not isinstance(provider["regexParams"], list):
            raise ValueError(f"providers[{index}].regexParams must be a list")


def main():
    parser = argparse.ArgumentParser(description="Fetch upstream rules and generate assets/parsedRules.json")
    parser.add_argument("--output", default="assets/parsedRules.json", help="Output path for parsed rules")
    args = parser.parse_args()

    txt_content = fetch_ublock_removeparam_txt()
    clearurls_root = fetch_clearurls_data_json()
    parsed_rules = build_parsed_rules(txt_content, clearurls_root)
    validate_parsed_rules(parsed_rules)

    root = Path(__file__).resolve().parents[1]
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = root / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)

    output_path.write_text(json.dumps(parsed_rules, separators=(",", ":"), ensure_ascii=True), encoding="utf-8")
    print(f"Wrote parsed rules: {output_path}")


if __name__ == "__main__":
    main()
