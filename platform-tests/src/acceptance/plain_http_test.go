package acceptance_test

import (
	"fmt"
	"net"
	"net/http"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("plain HTTP requests", func() {
	const (
		CONNECTION_TIMEOUT = 11 * time.Second
	)

	Describe("to the API", func() {
		It("has the connection refused", func() {
			uri := config.ApiEndpoint + ":80"
			_, err := net.DialTimeout("tcp", uri, CONNECTION_TIMEOUT)
			Expect(err).To(HaveOccurred(), "should not connect")
			Expect(err.(net.Error).Timeout()).To(BeTrue(), "should timeout")
		})
	})

	Describe("to an app", func() {
		It("is redirected to the https endpoint", func() {
			req, err := http.NewRequest("GET", fmt.Sprintf("http://foo.%s/", config.AppsDomain), nil)
			Expect(err).NotTo(HaveOccurred())
			resp, err := http.DefaultTransport.RoundTrip(req)
			Expect(err).NotTo(HaveOccurred())

			Expect(resp.StatusCode).To(Equal(301))
			Expect(resp.Header.Get("Location")).To(Equal(fmt.Sprintf("https://foo.%s/", config.AppsDomain)))
		})

		It("has any path and query components removed when redirecting", func() {
			req, err := http.NewRequest("GET", fmt.Sprintf("http://foo.%s/bar?baz=qux", config.AppsDomain), nil)
			Expect(err).NotTo(HaveOccurred())
			resp, err := http.DefaultTransport.RoundTrip(req)
			Expect(err).NotTo(HaveOccurred())

			Expect(resp.StatusCode).To(Equal(301))
			Expect(resp.Header.Get("Location")).To(Equal(fmt.Sprintf("https://foo.%s/", config.AppsDomain)))
		})
	})
})
