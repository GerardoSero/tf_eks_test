// Run this from the main folder
// 1. aws eks update-kubeconfig --profile sandbox --name tf-eks-demo --kubeconfig ./.tmp/kubeconfig
// 2a. LB_URL=$(kubectl --kubeconfig=.tmp/kubeconfig get svc/kong-ingress-kong-proxy -n ingress -ojson | jq -r ".status.loadBalancer.ingress | .[] | .hostname") k6 run --include-system-env-vars k6/stress_test.js
// 2b. LB_URL=$(kubectl --kubeconfig=.tmp/kubeconfig get svc/nginx-ingress-ingress-nginx-controller -n ingress -ojson | jq -r ".status.loadBalancer.ingress | .[] | .hostname") k6 run --include-system-env-vars k6/stress_test.js

import http from 'k6/http';
import { check, group, sleep } from 'k6';
export let options = {
  stages: [
    { duration: '2m', target: 3000 }, // simulate ramp-up of traffic from 1 to 100 users over 5 minutes.
    { duration: '10m', target: 3000 }, // stay at 100 users for 10 minutes
    { duration: '30s', target: 0 }, // ramp-down to 0 users
  ],
  thresholds: {
    http_req_failed: ['rate < 0.01'],
    http_req_duration: ['p(95)<300'], // 99% of requests must complete below 1.5s
    'logged in successfully': ['p(95)<300'], // 99% of requests must complete below 1.5s
  },
};

export default () => {
  const BASE_URL = `http://${__ENV.LB_URL}`;
  for(let i = 1; i <= 20; i++) { 
    let echoResponse = http.get(`${BASE_URL}/echo`);
    check(echoResponse, { 'is status 200': (r) => r.status === 200 });
  }

  // let hpaResponse = http.get(`${BASE_URL}/hpa`);
  // check(hpaResponse, { 'is status 200': (r) => r.status === 200 });

  sleep(1);
};
