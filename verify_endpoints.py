#!/usr/bin/env python3
import requests
import sys


def check_endpoint(url, expected_status=200):
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == expected_status:
            print(f"{url} - Status: {response.status_code}")
            return True
        else:
            print(
                f"{url} - Status: {response.status_code} (expected {expected_status})"
            )
            return False
    except Exception as e:
        print(f"{url} - Error: {str(e)}")
        return False


def main():
    alb_dns = "services-alb-1402427192.us-east-1.elb.amazonaws.com"
    base_url = f"http://{alb_dns}"

    endpoints = [
        f"{base_url}/service1",
        f"{base_url}/service2",
    ]

    print(f"Testing endpoints for ALB: {alb_dns}\n")

    results = [check_endpoint(endpoint) for endpoint in endpoints]

    print(f"\nResults: {sum(results)}/{len(results)} endpoints healthy")

    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
